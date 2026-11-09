import { error, json } from '@sveltejs/kit';
import { eq } from 'drizzle-orm';
import { db, media } from '$lib/server/db';
import { deleteObject, putImage, sniffImage } from '$lib/server/images';
import { ownedUpload } from '$lib/server/owned-upload';
import type { RequestHandler } from './$types';

const MAX = 1_500_000;

/**
 * Body: a small JPEG/WebP/PNG of the photo (or the video's first frame), at most 1.5 MB. Sent by the apps when
 * they wait for Wi-Fi to send the original: the post shows up in the diary right away with this picture
 * (`status: 'preview'`), and the processed original replaces it later.
 */
export const PUT: RequestHandler = async ({ params, request, locals }) => {
	const m = await ownedUpload(params.id, locals.user!.id);
	if (m.status !== 'uploading') error(409, 'Este envio já terminou.');
	const body = new Uint8Array(await request.arrayBuffer());
	if (!body.length || body.length > MAX) error(400, 'Prévia grande demais.');
	const kind = sniffImage(body);
	if (!kind) error(400, 'A prévia precisa ser uma imagem.');
	const key = await putImage(`previews/${m.userId}/${m.id}`, body, kind);
	await db().update(media).set({ previewKey: key }).where(eq(media.id, m.id));
	await deleteObject(m.previewKey);
	return json({ ok: true });
};
