import { json } from '@sveltejs/kit';
import { deleteMedia, mediaDetail, updateMedia } from '$lib/server/details';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ params }) => json(await mediaDetail(params.id));

/** Owner: `{ caption?, lat?, lng? }` (lat+lng together set a manual location). */
export const PATCH: RequestHandler = async ({ params, request, locals }) => {
	await updateMedia(params.id, locals.user!.id, await body(request));
	return json((await mediaDetail(params.id)).item);
};

export const DELETE: RequestHandler = async ({ params, locals }) => {
	await deleteMedia(params.id, locals.user!.id);
	return json({ ok: true });
};
