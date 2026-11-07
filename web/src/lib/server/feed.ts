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

export async function feed(): Promise<FeedItem[]> {
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

	const mItems: FeedMedia[] = await Promise.all(
		mRows.map(async ({ m, n }) => {
			const at = (m.takenAt ?? m.createdAt).toISOString();
			return {
				type: 'media' as const,
				id: m.id,
				userId: m.userId,
				at,
				day: dayKey(at),
				kind: m.kind,
				status: m.status as FeedMedia['status'],
				thumb: await mediaUrl(m.thumbKey),
				image: await mediaUrl(m.mediumKey ?? m.displayKey ?? m.posterKey),
				video: m.kind === 'video' ? await mediaUrl(m.videoKey) : null,
				width: m.width,
				height: m.height,
				likers: likers.get(m.id) ?? [],
				lat: m.lat,
				lng: m.lng,
				caption: m.caption,
				comments: n ?? 0,
				durationS: m.durationS
			};
		})
	);
	const cItems: FeedCheckin[] = await Promise.all(cRows.map(async ({ c, n }) => ({
		type: 'checkin',
		id: c.id,
		userId: c.userId,
		at: c.createdAt.toISOString(),
		day: dayKey(c.createdAt),
		lat: c.lat,
		lng: c.lng,
		note: c.note,
		snapshot: await mediaUrl(c.snapshotKey),
		comments: n ?? 0,
		likers: likers.get(c.id) ?? []
	})));
	return [...mItems, ...cItems].sort((a, b) => a.at.localeCompare(b.at));
}
