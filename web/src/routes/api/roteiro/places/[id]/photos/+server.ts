import { error, json } from '@sveltejs/kit';
import { count, eq } from 'drizzle-orm';
import { db, placePhotos } from '$lib/server/db';
import { putImage, sniffImage } from '$lib/server/images';
import { mediaUrl } from '$lib/server/r2';
import { placeExists } from '$lib/server/roteiro';
import type { RequestHandler } from './$types';

const MAX_BYTES = 2 * 1024 * 1024; // the browser resizes to 1600 px first (usually 200–500 KB)
const MAX_PHOTOS = 12;

/** Body: one image (JPG/PNG/WebP) → { id, url } */
export const POST: RequestHandler = async ({ params, request, locals }) => {
	if (!(await placeExists(params.id))) error(404, 'Lugar não encontrado.');
	const [{ n }] = await db().select({ n: count() }).from(placePhotos).where(eq(placePhotos.placeId, params.id));
	if (n >= MAX_PHOTOS) error(400, `No máximo ${MAX_PHOTOS} fotos por lugar.`);
	const bytes = new Uint8Array(await request.arrayBuffer());
	if (bytes.length === 0) error(400, 'Imagem vazia.');
	if (bytes.length > MAX_BYTES) error(413, 'Imagem grande demais.');
	const kind = sniffImage(bytes);
	if (!kind) error(415, 'Formato não suportado. Use JPG, PNG ou WebP.');
	const key = await putImage(`places/${params.id}`, bytes, kind);
	const [row] = await db().insert(placePhotos).values({ placeId: params.id, key, userId: locals.user!.id }).returning({ id: placePhotos.id });
	return json({ id: row.id, url: await mediaUrl(key) }, { status: 201 });
};
