import { feedPage } from '$lib/server/feed';
import { forGuestPage } from '$lib/server/guest';
import type { PageServerLoad } from './$types';

/** Only the first page of the Diário (every day); the rest loads while scrolling, via GET /api/feed. */
export const load: PageServerLoad = async ({ depends, locals }) => {
	depends('app:feed');
	const page = await feedPage({ limit: 12 });
	const first = locals.guest ? forGuestPage(page) : page;
	return { first, day: 'all' };
};
