import { error, json } from '@sveltejs/kit';
import { removeComment } from '$lib/server/comments';
import type { RequestHandler } from './$types';

/** Deletes one of my comments. */
export const DELETE: RequestHandler = async ({ params, locals }) => {
	if (!(await removeComment(params.id, locals.user!.id))) error(404, 'Comentário não encontrado');
	return json({ ok: true });
};
