import { json } from '@sveltejs/kit';
import { dayRoute } from '$lib/server/roteiro';
import type { RequestHandler } from './$types';

/**
 * The day's path through its places, by street → { legs: [{ transport, coordinates: [[lng, lat]…], routed }] }.
 * With `?casa=…` (any value) it also goes from the asker's stay and back to it; apps before 0.4 don't send it
 * (they don't draw the stay).
 */
export const GET: RequestHandler = async ({ params, locals, url }) =>
	json(await dayRoute(params.date, url.searchParams.has('casa') ? locals.user!.id : undefined), {
		headers: { 'cache-control': 'private, max-age=300' }
	});
