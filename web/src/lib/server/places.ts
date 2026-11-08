import { PLACES } from '$lib/itinerary';

export type PlaceResult = { name: string; detail: string; lat: number; lng: number };

const fold = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();

/** Itinerary places whose name contains every word of the query (accents ignored). */
function itineraryMatches(q: string): PlaceResult[] {
	const words = fold(q).split(/\s+/).filter(Boolean);
	return Object.values(PLACES)
		.filter((p) => words.every((w) => fold(p.name).includes(w)))
		.map((p) => ({ name: p.name, detail: 'Roteiro da viagem', lat: p.lat, lng: p.lng }));
}

type PhotonFeature = {
	geometry: { coordinates: [number, number] };
	properties: Record<string, string | undefined>;
};

const cache = new Map<string, { at: number; results: PlaceResult[] }>();
const DAY = 86_400_000;

/**
 * Searches OpenStreetMap places with Photon (komoot's free geocoder, made for search-as-you-type),
 * ranked near `near` (the map the person is looking at). Results are cached for a day.
 */
async function photon(q: string, near: { lat: number; lng: number }): Promise<PlaceResult[]> {
	// round the bias point so nearby searches share the cache (≈ 10 km)
	const lat = near.lat.toFixed(1), lng = near.lng.toFixed(1);
	const key = `${fold(q)}|${lat}|${lng}`;
	const hit = cache.get(key);
	if (hit && Date.now() - hit.at < DAY) return hit.results;

	const url = new URL('https://photon.komoot.io/api/');
	url.searchParams.set('q', q);
	url.searchParams.set('lat', lat);
	url.searchParams.set('lon', lng);
	url.searchParams.set('limit', '8');
	const r = await fetch(url, {
		headers: { 'user-agent': 'curitiba-trip/1.0 (+https://github.com/nelsul/curitiba-trip)' },
		signal: AbortSignal.timeout(6000)
	});
	if (!r.ok) throw new Error(`photon ${r.status}`);
	const { features } = (await r.json()) as { features: PhotonFeature[] };
	const results = features
		.filter((f) => f.properties.name)
		.map(({ geometry, properties: p }) => ({
			name: p.name!,
			detail: [p.street && [p.street, p.housenumber].filter(Boolean).join(', '), p.district, p.city, p.state]
				.filter((x, i, a) => x && x !== p.name && a.indexOf(x) === i)
				.join(' · '),
			lng: geometry.coordinates[0],
			lat: geometry.coordinates[1]
		}));
	if (cache.size > 500) cache.clear();
	cache.set(key, { at: Date.now(), results });
	return results;
}

export async function searchPlaces(q: string, near: { lat: number; lng: number }): Promise<PlaceResult[]> {
	const mine = itineraryMatches(q);
	let found: PlaceResult[] = [];
	try {
		found = await photon(q, near);
	} catch (e) {
		if (!mine.length) throw e;
	}
	// itinerary first, without repeating the same spot
	const close = (a: PlaceResult, b: PlaceResult) => Math.abs(a.lat - b.lat) < 0.001 && Math.abs(a.lng - b.lng) < 0.001;
	return [...mine, ...found.filter((f) => !mine.some((m) => close(m, f)))].slice(0, 10);
}
