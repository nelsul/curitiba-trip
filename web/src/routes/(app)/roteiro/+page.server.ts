import { listDays, listPlaces, listStays } from '$lib/server/roteiro';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ depends, locals }) => {
	depends('app:roteiro');
	const [places, stays] = await Promise.all([listPlaces(), listStays()]);
	const days = await listDays(locals.user!.id, stays);
	return { places, stays, days };
};
