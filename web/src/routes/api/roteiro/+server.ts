import { json } from '@sveltejs/kit';
import { listDays, listPlaces } from '$lib/server/roteiro';
import type { RequestHandler } from './$types';

/** Everything the Roteiro shows: the shared places (with photos) and the days with their ordered stops. */
export const GET: RequestHandler = async () => {
	const [places, days] = await Promise.all([listPlaces(), listDays()]);
	return json({ places, days });
};
