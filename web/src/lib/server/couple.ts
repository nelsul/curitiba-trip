import { error } from '@sveltejs/kit';
import { and, asc, eq, gt, isNotNull, ne, or, inArray } from 'drizzle-orm';
import { checkins, db, likes, media, users, type CoupleRole } from './db';
import { mediaUrl } from './r2';

export type CoupleLike = {
	id: number;
	likerId: string;
	role: CoupleRole;
	mediaId: string | null;
	checkinId: string | null;
	at: string;
	/** a picture of the post (photo / video poster / check-in map) */
	image: string | null;
};

/** Likes by the bride or groom on my posts I haven't seen the special effect for yet (oldest first). */
export async function unseenCoupleLikes(me: string): Promise<CoupleLike[]> {
	const [u] = await db().select({ seen: users.seenCoupleLike }).from(users).where(eq(users.id, me));
	const couple = await db().select({ id: users.id, couple: users.couple }).from(users).where(and(isNotNull(users.couple), ne(users.id, me)));
	if (!u || !couple.length) return [];
	const role = new Map(couple.map((c) => [c.id, c.couple!]));
	const rows = await db()
		.select({
			id: likes.id,
			likerId: likes.userId,
			mediaId: likes.mediaId,
			checkinId: likes.checkinId,
			at: likes.createdAt,
			thumb: media.mediumKey,
			poster: media.posterKey,
			snapshot: checkins.snapshotKey
		})
		.from(likes)
		.leftJoin(media, eq(media.id, likes.mediaId))
		.leftJoin(checkins, eq(checkins.id, likes.checkinId))
		.where(
			and(
				gt(likes.id, u.seen),
				inArray(likes.userId, [...role.keys()]),
				or(eq(media.userId, me), eq(checkins.userId, me))
			)
		)
		.orderBy(asc(likes.id))
		.limit(20);
	return Promise.all(
		rows.map(async (r) => ({
			id: r.id,
			likerId: r.likerId,
			role: role.get(r.likerId)!,
			mediaId: r.mediaId,
			checkinId: r.checkinId,
			at: r.at.toISOString(),
			image: await mediaUrl(r.thumb ?? r.poster ?? r.snapshot)
		}))
	);
}

/** After showing the effect: never show likes up to `upTo` again. */
export async function markCoupleLikesSeen(me: string, upTo: unknown) {
	const n = Number(upTo);
	if (!Number.isSafeInteger(n) || n < 0) error(400, 'Valor inválido.');
	const [u] = await db().select({ seen: users.seenCoupleLike }).from(users).where(eq(users.id, me));
	if (u && n > u.seen) await db().update(users).set({ seenCoupleLike: n }).where(eq(users.id, me));
}
