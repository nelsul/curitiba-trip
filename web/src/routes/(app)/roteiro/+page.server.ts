import { people } from '$lib/server/feed';
import { listDays, listPlaces } from '$lib/server/roteiro';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ depends }) => {
	depends('app:roteiro');
	const [places, days, persons] = await Promise.all([listPlaces(), listDays(), people()]);
	return { places, days, persons };
};
