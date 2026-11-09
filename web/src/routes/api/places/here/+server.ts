import { error, json } from '@sveltejs/kit';
import { placeHere } from '$lib/server/places';
import type { RequestHandler } from './$types';

/** A short name for a point (the share frames' "local"): ?lat=&lng= → { name }. Falls back to "Curitiba". */
export const GET: RequestHandler = async ({ url }) => {
	const lat = Number(url.searchParams.get('lat'));
	const lng = Number(url.searchParams.get('lng'));
	if (!url.searchParams.has('lat') || !Number.isFinite(lat) || Math.abs(lat) > 90 || !Number.isFinite(lng) || Math.abs(lng) > 180) error(400, 'Local inválido');
	const name = await placeHere(lat, lng).catch(() => 'Curitiba');
	return json({ name }, { headers: { 'cache-control': 'private, max-age=3600' } });
};
