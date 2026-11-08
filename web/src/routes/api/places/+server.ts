import { error, json } from '@sveltejs/kit';
import { searchPlaces } from '$lib/server/places';
import type { RequestHandler } from './$types';

/**
 * Place search for marking where a photo/video was taken.
 * ?q=<text> (2–100 chars) · ?lat=&lng= ranks results near that point (default: Curitiba).
 * → [{ name, detail, lat, lng }], itinerary places first.
 */
export const GET: RequestHandler = async ({ url }) => {
	const q = (url.searchParams.get('q') ?? '').trim();
	if (q.length < 2 || q.length > 100) error(400, 'Digite pelo menos 2 letras.');
	const lat = Number(url.searchParams.get('lat'));
	const lng = Number(url.searchParams.get('lng'));
	const near =
		url.searchParams.has('lat') && Number.isFinite(lat) && Math.abs(lat) <= 90 && Number.isFinite(lng) && Math.abs(lng) <= 180
			? { lat, lng }
			: { lat: -25.4284, lng: -49.2733 };
	try {
		return json(await searchPlaces(q, near), { headers: { 'cache-control': 'private, max-age=3600' } });
	} catch {
		error(502, 'A busca de lugares não respondeu. Tente de novo ou marque no mapa.');
	}
};
