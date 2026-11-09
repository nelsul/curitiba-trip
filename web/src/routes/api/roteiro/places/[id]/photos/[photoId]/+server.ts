import { error, json } from '@sveltejs/kit';
import { and, eq } from 'drizzle-orm';
import { db, placePhotos } from '$lib/server/db';
import { deleteObject } from '$lib/server/images';
import type { RequestHandler } from './$types';

export const DELETE: RequestHandler = async ({ params }) => {
	if (!/^[0-9a-f-]{36}$/.test(params.photoId)) error(404, 'Foto não encontrada.');
	const [row] = await db()
		.delete(placePhotos)
		.where(and(eq(placePhotos.id, params.photoId), eq(placePhotos.placeId, params.id)))
		.returning({ key: placePhotos.key });
	if (!row) error(404, 'Foto não encontrada.');
	await deleteObject(row.key);
	return json({ ok: true });
};
