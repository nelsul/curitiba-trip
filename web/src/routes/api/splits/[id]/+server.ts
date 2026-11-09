import { json } from '@sveltejs/kit';
import { deleteSplit } from '$lib/server/splits';
import type { RequestHandler } from './$types';

/** Who paid (or an admin). */
export const DELETE: RequestHandler = async ({ params, locals }) => {
	await deleteSplit(params.id, locals.user!);
	return json({ ok: true });
};
