import { error, json } from '@sveltejs/kit';
import { and, eq } from 'drizzle-orm';
import { checkins, db } from '$lib/server/db';
import { deleteObject } from '$lib/server/images';
import type { RequestHandler } from './$types';

/** Only the person who checked in can delete it (comments and likes go with it). */
export const DELETE: RequestHandler = async ({ params, locals }) => {
	if (!/^[0-9a-f-]{36}$/.test(params.id)) error(404, 'Não encontrado');
	const [c] = await db()
		.delete(checkins)
		.where(and(eq(checkins.id, params.id), eq(checkins.userId, locals.user!.id)))
		.returning({ snapshotKey: checkins.snapshotKey });
	if (!c) error(403, 'Só quem fez o check-in pode apagar.');
	await deleteObject(c.snapshotKey);
	return json({ ok: true });
};
