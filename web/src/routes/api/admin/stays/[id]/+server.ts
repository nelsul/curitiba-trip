import { json } from '@sveltejs/kit';
import { deleteStay, saveStay } from '$lib/server/roteiro';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** Replaces the stay and its guest list (same body as POST /api/admin/stays). */
export const PUT: RequestHandler = async ({ params, request }) => {
	await saveStay(params.id, await body(request));
	return json({ ok: true });
};

export const DELETE: RequestHandler = async ({ params }) => {
	await deleteStay(params.id);
	return json({ ok: true });
};
