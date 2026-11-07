import { json } from '@sveltejs/kit';
import { islandStyle } from '$lib/map-style';
import type { RequestHandler } from './$types';

let cached: { at: number; style: unknown } | null = null;

/** The island night map style (MapLibre style JSON), identical to the web map. Cached for an hour. */
export const GET: RequestHandler = async () => {
	if (!cached || Date.now() - cached.at > 3600_000) cached = { at: Date.now(), style: await islandStyle(true) };
	return json(cached.style, { headers: { 'cache-control': 'private, max-age=3600' } });
};
