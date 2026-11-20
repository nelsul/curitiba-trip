import { json } from '@sveltejs/kit';
import { feedPage, feedQuery } from '$lib/server/feed';
import { forGuestPage } from '$lib/server/guest';
import type { RequestHandler } from './$types';

/**
 * Newest-first posts (carousels already grouped, like the web feed).
 * ?limit=1..100 (default 20) · ?before=<nextCursor> · ?day=YYYY-MM-DD · ?person=<userId>
 * `days` lists every day that has posts (ignoring the filters), for the day chips.
 */
export const GET: RequestHandler = async ({ url, locals }) => {
	const page = await feedPage(feedQuery(url));
	return json(locals.guest ? forGuestPage(page) : page);
};
