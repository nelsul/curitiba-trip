import { feedPage } from '$lib/server/feed';
import { dayKey } from '$lib/format';
import { TRIP_DAYS } from '$lib/trip';
import type { PageServerLoad } from './$types';

/** Only the first page of the Diário (today during the trip); the rest loads while scrolling, via GET /api/feed. */
export const load: PageServerLoad = async ({ depends }) => {
	depends('app:feed');
	const today = dayKey(Date.now());
	const day = TRIP_DAYS.includes(today) ? today : 'all';
	const first = await feedPage({ limit: 12, day: day === 'all' ? null : day });
	return { first, day };
};
