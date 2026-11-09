import { error } from '@sveltejs/kit';
import { asc, isNotNull, ne, or, sql } from 'drizzle-orm';
import { checkins, comments, db, likes, media, users } from './db';
import { mediaUrl } from './r2';
import { dayKey } from '$lib/format';
import { groupPosts, isOlderThan, postCursor, type Post } from '$lib/feed-group';
import type { FeedCheckin, FeedItem, FeedMedia, Person } from '$lib/types';

export async function people(): Promise<Person[]> {
	const rows = await db()
		.select({ id: users.id, name: users.name, color: users.color, avatarKey: users.avatarKey })
		.from(users)
		.orderBy(asc(users.name));
	return Promise.all(rows.map(async ({ avatarKey, ...u }) => ({ ...u, photo: await mediaUrl(avatarKey) })));
}

type MediaKeys = { thumb: string | null; image: string | null; video: string | null };
type Unsigned = { items: FeedItem[]; keys: Map<string, MediaKeys | { snapshot: string | null }> };

/**
 * All feed items (oldest first) with their R2 keys, but no URLs yet. Signing URLs is the slow part,
 * so the paginated API only signs the page it returns (signItems).
 */
export async function feedUnsigned(): Promise<Unsigned> {
	const counts = db()
		.select({
			mediaId: comments.mediaId,
			checkinId: comments.checkinId,
			n: sql<number>`count(*)::int`.as('n')
		})
		.from(comments)
		.groupBy(comments.mediaId, comments.checkinId)
		.as('counts');

	const [mRows, cRows, likeRows] = await Promise.all([
		db()
			.select({ m: media, n: counts.n })
			.from(media)
			.leftJoin(counts, sql`${counts.mediaId} = ${media.id}`)
			// waiting for Wi-Fi: shown with its low-res preview
			.where(or(ne(media.status, 'uploading'), isNotNull(media.previewKey))),
		db()
			.select({ c: checkins, n: counts.n })
			.from(checkins)
			.leftJoin(counts, sql`${counts.checkinId} = ${checkins.id}`),
		db().select({ userId: likes.userId, mediaId: likes.mediaId, checkinId: likes.checkinId }).from(likes).orderBy(asc(likes.createdAt))
	]);
	const likers = new Map<string, string[]>();
	for (const l of likeRows) {
		const k = (l.mediaId ?? l.checkinId)!;
		(likers.get(k) ?? likers.set(k, []).get(k)!).push(l.userId);
	}

	const keys: Unsigned['keys'] = new Map();
	const mItems: FeedMedia[] = mRows.map(({ m, n }) => {
		const at = (m.takenAt ?? m.createdAt).toISOString();
		keys.set(m.id, {
			thumb: m.thumbKey ?? m.previewKey,
			image: m.mediumKey ?? m.displayKey ?? m.posterKey ?? m.previewKey,
			video: m.kind === 'video' ? m.videoKey : null
		});
		return {
			type: 'media' as const,
			id: m.id,
			userId: m.userId,
			at,
			day: dayKey(at),
			kind: m.kind,
			status: (m.status === 'uploading' ? 'preview' : m.status) as FeedMedia['status'],
			thumb: null,
			image: null,
			video: null,
			width: m.width,
			height: m.height,
			likers: likers.get(m.id) ?? [],
			lat: m.lat,
			lng: m.lng,
			caption: m.caption,
			comments: n ?? 0,
			durationS: m.durationS
		};
	});
	const cItems: FeedCheckin[] = cRows.map(({ c, n }) => {
		keys.set(c.id, { snapshot: c.snapshotKey });
		return {
			type: 'checkin',
			id: c.id,
			userId: c.userId,
			at: c.createdAt.toISOString(),
			day: dayKey(c.createdAt),
			lat: c.lat,
			lng: c.lng,
			note: c.note,
			snapshot: null,
			comments: n ?? 0,
			likers: likers.get(c.id) ?? []
		};
	});
	return { items: [...mItems, ...cItems].sort((a, b) => a.at.localeCompare(b.at)), keys };
}

/** Fills in presigned URLs (stable for a day, so browsers and the app can cache them). */
export async function signItems<T extends FeedItem>(items: T[], keys: Unsigned['keys']): Promise<T[]> {
	return Promise.all(
		items.map(async (it) => {
			const k = keys.get(it.id);
			if (it.type === 'media' && k && 'thumb' in k) {
				const [thumb, image, video] = await Promise.all([mediaUrl(k.thumb), mediaUrl(k.image), mediaUrl(k.video)]);
				return { ...it, thumb, image, video };
			}
			if (it.type === 'checkin' && k && 'snapshot' in k) return { ...it, snapshot: await mediaUrl(k.snapshot) };
			return it;
		})
	);
}

export type FeedQuery = { limit: number; before?: string | null; day?: string | null; person?: string | null };
/** Query string of GET /api/feed and /api/feed/media (throws 400 on bad input). */
export function feedQuery(url: URL) {
	const limit = Math.min(100, Math.max(1, Number(url.searchParams.get('limit')) || 20));
	const before = url.searchParams.get('before');
	const day = url.searchParams.get('day');
	const person = url.searchParams.get('person');
	if (day && !/^\d{4}-\d{2}-\d{2}$/.test(day)) error(400, 'Dia inválido');
	if (before && !/^\d{4}-\d{2}-\d{2}T[\d:.]+Z\|[mc][0-9a-f-]{36}$/.test(before)) error(400, 'Cursor inválido');
	if (person && !/^[0-9a-f-]{36}$/.test(person)) error(400, 'Pessoa inválida');
	return { limit, before, day, person };
}

export type FeedPage = { posts: Post[]; nextCursor: string | null; days: string[] };

/** One page of newest-first posts (carousels grouped), only that page signed. GET /api/feed and the web Diário. */
export async function feedPage({ limit, before, day, person }: FeedQuery): Promise<FeedPage> {
	const { items, keys } = await feedUnsigned();
	const filtered = items.filter((i) => (!day || i.day === day) && (!person || i.userId === person));
	const all = groupPosts(filtered);
	const start = before ? all.filter((p) => isOlderThan(p, before)) : all;
	const page = start.slice(0, limit);
	const posts: Post[] = await Promise.all(
		page.map(async (p) =>
			p.type === 'media' ? { ...p, items: await signItems(p.items, keys) } : { ...p, item: (await signItems([p.item], keys))[0] }
		)
	);
	const days = [...new Set(items.map((i) => i.day))].sort();
	return { posts, nextCursor: start.length > limit ? postCursor(page.at(-1)!) : null, days };
}

/** Every ready photo and video, newest first, in one response: the "Todas as fotos" grid and its reels. */
export async function gridMedia({ day, person }: { day?: string | null; person?: string | null }): Promise<FeedMedia[]> {
	const { items, keys } = await feedUnsigned();
	const media = items
		.filter((i): i is FeedMedia => i.type === 'media' && i.status === 'ready' && (!day || i.day === day) && (!person || i.userId === person))
		.filter((m) => {
			const k = keys.get(m.id);
			return !!k && 'thumb' in k && !!(k.image || k.video);
		})
		.sort((a, b) => b.at.localeCompare(a.at) || b.id.localeCompare(a.id));
	return signItems(media, keys);
}

/** Everything, signed (web feed and map). */
export async function feed(): Promise<FeedItem[]> {
	const { items, keys } = await feedUnsigned();
	return signItems(items, keys);
}
