import { json } from '@sveltejs/kit';
import { setRetro } from '$lib/server/retro';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** Admin: `{ mediaIds: [...] }`, the Retrospectiva in order (replaces the list). */
export const PUT: RequestHandler = async ({ request }) => {
	const { mediaIds } = await body<{ mediaIds?: unknown }>(request);
	await setRetro(mediaIds);
	return json({ ok: true });
};
