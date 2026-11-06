import { error, json as reply } from '@sveltejs/kit';
import { db, locationPings } from '$lib/server/db';
import { latestLocations } from '$lib/server/locations';
import { isLat, isLng, json } from '$lib/server/validate';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request, locals }) => {
	const b = await json<{ lat: number; lng: number; accuracy?: number }>(request);
	if (!isLat(b.lat) || !isLng(b.lng)) error(400, 'Posição inválida');
	await db()
		.insert(locationPings)
		.values({ userId: locals.user!.id, lat: b.lat, lng: b.lng, accuracyM: Number(b.accuracy) || null });
	return reply({ ok: true });
};

export const GET: RequestHandler = async () => reply(await latestLocations());
