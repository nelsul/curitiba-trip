import { error, json } from '@sveltejs/kit';
import { mapData } from '$lib/server/map-data';
import type { RequestHandler } from './$types';

/** Map layers: located posts/check-ins, trails (pings) and latest positions. ?day=YYYY-MM-DD limits posts and trails to one day. */
export const GET: RequestHandler = async ({ url }) => {
	const day = url.searchParams.get('day');
	if (day && !/^\d{4}-\d{2}-\d{2}$/.test(day)) error(400, 'Dia inválido');
	return json(await mapData(day));
};
