import { error, json as reply } from '@sveltejs/kit';
import { and, asc, eq } from 'drizzle-orm';
import { db, favorites, media } from '$lib/server/db';
import { json } from '$lib/server/validate';
import type { RequestHandler } from './$types';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/** Star or unstar a photo/video for the Retrospectiva. Idempotent; returns who starred it now. */
export const POST: RequestHandler = async ({ request, locals }) => {
	const b = await json<{ mediaId?: string; fav: boolean }>(request);
	if (!b.mediaId || !UUID.test(b.mediaId)) error(400, 'Item inválido');
	const [m] = await db().select({ id: media.id }).from(media).where(eq(media.id, b.mediaId));
	if (!m) error(404, 'Não encontrado');
	const userId = locals.user!.id;
	if (b.fav) await db().insert(favorites).values({ userId, mediaId: m.id }).onConflictDoNothing();
	else await db().delete(favorites).where(and(eq(favorites.userId, userId), eq(favorites.mediaId, m.id)));
	const rows = await db().select({ userId: favorites.userId }).from(favorites).where(eq(favorites.mediaId, m.id)).orderBy(asc(favorites.createdAt));
	return reply({ favs: rows.map((r) => r.userId) });
};
