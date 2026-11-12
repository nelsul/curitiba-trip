import { error, json, redirect } from '@sveltejs/kit';
import { eq } from 'drizzle-orm';
import { db, media } from '$lib/server/db';
import { mediaUrl } from '$lib/server/r2';
import type { RequestHandler } from './$types';

/**
 * The original file as uploaded (full quality, its own name), for "Salvar original":
 * 302 to a signed R2 link that downloads it. 404 until the original has arrived (still uploading).
 * `?link` answers `{ url, name }` instead (the apps download it themselves, without their token going to R2).
 */
export const GET: RequestHandler = async ({ params, url: req }) => {
	if (!/^[0-9a-f-]{36}$/.test(params.id)) error(404, 'Não encontrado');
	const [m] = await db()
		.select({ key: media.originalKey, name: media.originalName, status: media.status })
		.from(media)
		.where(eq(media.id, params.id));
	if (!m || m.status === 'uploading') error(404, 'O original ainda não chegou.');
	const url = await mediaUrl(m.key, m.name);
	if (!url) error(404, 'Não encontrado');
	if (req.searchParams.has('link')) return json({ url, name: m.name });
	redirect(302, url);
};
