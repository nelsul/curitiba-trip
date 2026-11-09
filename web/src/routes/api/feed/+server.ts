import { json } from '@sveltejs/kit';
import { feedPage, feedQuery } from '$lib/server/feed';
import type { RequestHandler } from './$types';

/**
 * Newest-first posts (carousels already grouped, like the web feed).
 * ?limit=1..100 (default 20) · ?before=<nextCursor> · ?day=YYYY-MM-DD · ?person=<userId>
 * `days` lists every day that has posts (ignoring the filters), for the day chips.
 */
export const GET: RequestHandler = async ({ url }) => {
	return json(await feedPage(feedQuery(url)));
};
