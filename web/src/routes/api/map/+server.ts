import { error, json } from '@sveltejs/kit';
import { mapData } from '$lib/server/map-data';
import type { RequestHandler } from './$types';

/** Map layers: located posts/check-ins and latest positions (`pings` is always empty now). ?day=YYYY-MM-DD limits posts to one day. */
export const GET: RequestHandler = async ({ url }) => {
	const day = url.searchParams.get('day');
	if (day && !/^\d{4}-\d{2}-\d{2}$/.test(day)) error(400, 'Dia inválido');
	return json(await mapData(day));
};
