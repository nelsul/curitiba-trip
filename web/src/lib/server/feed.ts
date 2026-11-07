import { asc, ne, sql } from 'drizzle-orm';
import { checkins, comments, db, likes, media, users } from './db';
import { mediaUrl } from './r2';
import { dayKey } from '$lib/format';
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
			.where(ne(media.status, 'uploading')),
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
			thumb: m.thumbKey,
			image: m.mediumKey ?? m.displayKey ?? m.posterKey,
			video: m.kind === 'video' ? m.videoKey : null
		});
		return {
			type: 'media' as const,
			id: m.id,
			userId: m.userId,
			at,
			day: dayKey(at),
			kind: m.kind,
			status: m.status as FeedMedia['status'],
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

/** Everything, signed (web feed and map). */
export async function feed(): Promise<FeedItem[]> {
	const { items, keys } = await feedUnsigned();
	return signItems(items, keys);
}
