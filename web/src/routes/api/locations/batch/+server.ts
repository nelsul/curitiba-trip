import { error, json as reply } from '@sveltejs/kit';
import { desc, eq } from 'drizzle-orm';
import { db, locationPings } from '$lib/server/db';
import { isLat, isLng, json } from '$lib/server/validate';
import type { RequestHandler } from './$types';

const MAX_POINTS = 500;
const MAX_AGE_MS = 48 * 3600_000;
const MIN_DISTANCE_M = 30;
const MIN_GAP_MS = 3 * 60_000;

function distanceM(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
	const R = 6371e3, rad = Math.PI / 180;
	const dLat = (b.lat - a.lat) * rad, dLng = (b.lng - a.lng) * rad;
	const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLng / 2) ** 2;
	return 2 * R * Math.asin(Math.sqrt(h));
}

/**
 * Background locations from the iOS app: `[{ lat, lng, accuracy?, at }]` with the time each point was recorded.
 * Points older than 48 h, in the future, imprecise (>500 m) or too close to the previous kept point are dropped.
 */
export const POST: RequestHandler = async ({ request, locals }) => {
	const body = await json<{ lat: number; lng: number; accuracy?: number; at: string }[]>(request);
	if (!Array.isArray(body) || body.length > MAX_POINTS) error(400, `Envie de 1 a ${MAX_POINTS} pontos.`);
	const now = Date.now();
	const points = body
		.map((p) => ({ lat: p?.lat, lng: p?.lng, accuracyM: Number(p?.accuracy) || null, at: new Date(p?.at) }))
		.filter((p) => isLat(p.lat) && isLng(p.lng) && !Number.isNaN(p.at.getTime()))
		.filter((p) => p.at.getTime() <= now + 120_000 && now - p.at.getTime() <= MAX_AGE_MS && (p.accuracyM ?? 0) <= 500)
		.sort((a, b) => a.at.getTime() - b.at.getTime());

	const userId = locals.user!.id;
	const [last] = await db()
		.select({ lat: locationPings.lat, lng: locationPings.lng, at: locationPings.createdAt })
		.from(locationPings)
		.where(eq(locationPings.userId, userId))
		.orderBy(desc(locationPings.createdAt))
		.limit(1);
	let prev = last ? { lat: last.lat, lng: last.lng, t: last.at.getTime() } : null;
	const keep = [];
	for (const p of points) {
		if (prev && distanceM(prev, p) < MIN_DISTANCE_M && Math.abs(p.at.getTime() - prev.t) < MIN_GAP_MS) continue;
		keep.push({ userId, lat: p.lat as number, lng: p.lng as number, accuracyM: p.accuracyM, createdAt: p.at });
		prev = { lat: p.lat as number, lng: p.lng as number, t: p.at.getTime() };
	}
	if (keep.length) await db().insert(locationPings).values(keep);
	return reply({ received: body.length, stored: keep.length });
};
