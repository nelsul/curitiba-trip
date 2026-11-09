import { json } from '@sveltejs/kit';
import { tripWeather } from '$lib/server/weather';
import type { RequestHandler } from './$types';

/** `{ days: [{ date, min, max, rain, kind, hours: [{ time, temp, rain, kind }] }], updatedAt }` for the trip days. */
export const GET: RequestHandler = async () => json(await tripWeather(), { headers: { 'cache-control': 'private, max-age=600' } });
