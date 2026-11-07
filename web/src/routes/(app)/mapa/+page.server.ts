import { people } from '$lib/server/feed';
import { mapData } from '$lib/server/map-data';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ depends }) => {
	depends('app:feed');
	const [data, persons] = await Promise.all([mapData(), people()]);
	return { persons, ...data };
};
