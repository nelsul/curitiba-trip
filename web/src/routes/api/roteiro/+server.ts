import { json } from '@sveltejs/kit';
import { listDays, listPlaces, listStays } from '$lib/server/roteiro';
import type { RequestHandler } from './$types';

/**
 * Everything the Roteiro shows: the shared places (with photos), the stays (hotel/Airbnb) and the days with
 * their ordered stops. Each day's `startStay`/`endStay` is where the person asking sleeps.
 */
export const GET: RequestHandler = async ({ locals }) => {
	const [places, stays] = await Promise.all([listPlaces(), listStays()]);
	const days = await listDays(locals.user!.id, stays);
	return json({ places, stays, days });
};
