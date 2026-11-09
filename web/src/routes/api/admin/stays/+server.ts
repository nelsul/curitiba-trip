import { json } from '@sveltejs/kit';
import { listStays, saveStay } from '$lib/server/roteiro';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

// /api/admin/* is admins only (hooks.server.ts).

/** All stays (hotel/Airbnb) with their guests' user ids. */
export const GET: RequestHandler = async () => json({ stays: await listStays() });

/** New stay → { id }. Body: { name, kind, lat, lng, address?, link?, checkIn?, checkOut?, note?, guests: [userId] } */
export const POST: RequestHandler = async ({ request }) => json({ id: await saveStay(null, await body(request)) }, { status: 201 });
