import { json } from '@sveltejs/kit';
import { itineraryForApps } from '$lib/server/roteiro';
import type { RequestHandler } from './$types';

/** The day-by-day itinerary (edited by the group on /roteiro), with places and Google Maps / Uber links ready to open. */
export const GET: RequestHandler = async () => json(await itineraryForApps());
