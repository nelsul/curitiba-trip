import { error } from '@sveltejs/kit';
import { listDays, listPlaces } from '$lib/server/roteiro';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params, locals, depends }) => {
	depends('app:roteiro');
	const [places, days] = await Promise.all([listPlaces(), listDays(locals.user!.id)]);
	const place = places.find((p) => p.id === params.id);
	if (!place) error(404, 'Lugar não encontrado');
	const stops = days.flatMap((d) => d.stops.filter((s) => s.placeId === place.id).map((s) => ({ ...s, date: d.date, dayTitle: d.title })));
	return { place, stops };
};
