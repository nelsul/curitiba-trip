import { feedPage } from '$lib/server/feed';
import type { PageServerLoad } from './$types';

/** Only the first page of the Diário (every day); the rest loads while scrolling, via GET /api/feed. */
export const load: PageServerLoad = async ({ depends }) => {
	depends('app:feed');
	const first = await feedPage({ limit: 12 });
	return { first, day: 'all' };
};
