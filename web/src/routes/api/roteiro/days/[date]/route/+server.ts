import { json } from '@sveltejs/kit';
import { dayRoute } from '$lib/server/roteiro';
import type { RequestHandler } from './$types';

/** The day's path through its places, by street → { legs: [{ transport, coordinates: [[lng, lat]…], routed }] } */
export const GET: RequestHandler = async ({ params }) =>
	json(await dayRoute(params.date), { headers: { 'cache-control': 'private, max-age=300' } });
