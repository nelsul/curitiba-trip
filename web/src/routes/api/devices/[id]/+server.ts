import { error, json } from '@sveltejs/kit';
import { and, eq, like } from 'drizzle-orm';
import { db, sessions } from '$lib/server/db';
import type { RequestHandler } from './$types';

/** Signs one of my devices out (by the short handle from GET /api/devices). */
export const DELETE: RequestHandler = async ({ params, locals }) => {
	if (!/^[0-9a-f]{16}$/.test(params.id)) error(404, 'Aparelho não encontrado');
	const gone = await db()
		.delete(sessions)
		.where(and(eq(sessions.userId, locals.user!.id), eq(sessions.kind, 'device'), like(sessions.id, `${params.id}%`)))
		.returning({ id: sessions.id });
	if (!gone.length) error(404, 'Aparelho não encontrado');
	return json({ ok: true });
};
