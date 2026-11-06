import { error, json as reply } from '@sveltejs/kit';
import { checkins, db, locationPings } from '$lib/server/db';
import { clip, isLat, isLng, json } from '$lib/server/validate';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request, locals }) => {
	const b = await json<{ lat: number; lng: number; accuracy?: number; note?: string }>(request);
	if (!isLat(b.lat) || !isLng(b.lng)) error(400, 'Posição inválida');
	const accuracyM = Number(b.accuracy) || null;
	const [c] = await db()
		.insert(checkins)
		.values({ userId: locals.user!.id, lat: b.lat, lng: b.lng, accuracyM, note: clip(b.note, 2000) })
		.returning({ id: checkins.id });
	await db().insert(locationPings).values({ userId: locals.user!.id, lat: b.lat, lng: b.lng, accuracyM });
	return reply({ id: c.id });
};
