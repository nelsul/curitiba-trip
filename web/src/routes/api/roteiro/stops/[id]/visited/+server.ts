import { json } from '@sveltejs/kit';
import { setVisited } from '$lib/server/roteiro';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** "Fomos!": { visited: true | false } → { visitedAt, visitedBy }. One tick counts for the whole group. */
export const POST: RequestHandler = async ({ params, request, locals }) => {
	const b = await body<{ visited?: unknown }>(request);
	return json(await setVisited(params.id, b.visited === true, locals.user!.id));
};
