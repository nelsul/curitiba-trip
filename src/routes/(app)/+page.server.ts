import { feed, people } from '$lib/server/feed';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ depends }) => {
	depends('app:feed');
	const [items, persons] = await Promise.all([feed(), people()]);
	return { items, persons };
};
