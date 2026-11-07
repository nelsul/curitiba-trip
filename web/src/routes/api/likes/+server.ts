import { error, json as reply } from '@sveltejs/kit';
import { and, asc, eq } from 'drizzle-orm';
import { checkins, db, likes, media } from '$lib/server/db';
import { json } from '$lib/server/validate';
import type { RequestHandler } from './$types';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/** Like or unlike a photo/video or a check-in. Idempotent; returns who likes it now. */
export const POST: RequestHandler = async ({ request, locals }) => {
	const b = await json<{ mediaId?: string; checkinId?: string; liked: boolean }>(request);
	const userId = locals.user!.id;
	let target;
	if (b.mediaId && UUID.test(b.mediaId)) {
		const [m] = await db().select({ id: media.id }).from(media).where(eq(media.id, b.mediaId));
		if (!m) error(404, 'Não encontrado');
		target = { col: likes.mediaId, value: { mediaId: m.id } };
	} else if (b.checkinId && UUID.test(b.checkinId)) {
		const [c] = await db().select({ id: checkins.id }).from(checkins).where(eq(checkins.id, b.checkinId));
		if (!c) error(404, 'Não encontrado');
		target = { col: likes.checkinId, value: { checkinId: c.id } };
	} else error(400, 'Item inválido');

	const id = Object.values(target.value)[0];
	if (b.liked) await db().insert(likes).values({ userId, ...target.value }).onConflictDoNothing();
	else await db().delete(likes).where(and(eq(likes.userId, userId), eq(target.col, id)));

	const rows = await db().select({ userId: likes.userId }).from(likes).where(eq(target.col, id)).orderBy(asc(likes.createdAt));
	return reply({ likers: rows.map((r) => r.userId) });
};
