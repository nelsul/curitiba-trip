import { asc, ne, sql } from 'drizzle-orm';
import { checkins, comments, db, media, users } from './db';
import { mediaUrl } from './r2';
import { dayKey } from '$lib/format';
import type { FeedCheckin, FeedItem, FeedMedia, Person } from '$lib/types';

export async function people(): Promise<Person[]> {
	return db().select({ id: users.id, name: users.name, color: users.color }).from(users).orderBy(asc(users.name));
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

	const [mRows, cRows] = await Promise.all([
		db()
			.select({ m: media, n: counts.n })
			.from(media)
			.leftJoin(counts, sql`${counts.mediaId} = ${media.id}`)
			.where(ne(media.status, 'uploading')),
		db()
			.select({ c: checkins, n: counts.n })
			.from(checkins)
			.leftJoin(counts, sql`${counts.checkinId} = ${checkins.id}`)
	]);

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
				lat: m.lat,
				lng: m.lng,
				caption: m.caption,
				comments: n ?? 0,
				durationS: m.durationS
			};
		})
	);
	const cItems: FeedCheckin[] = cRows.map(({ c, n }) => ({
		type: 'checkin',
		id: c.id,
		userId: c.userId,
		at: c.createdAt.toISOString(),
		day: dayKey(c.createdAt),
		lat: c.lat,
		lng: c.lng,
		note: c.note,
		comments: n ?? 0
	}));
	return [...mItems, ...cItems].sort((a, b) => a.at.localeCompare(b.at));
}
