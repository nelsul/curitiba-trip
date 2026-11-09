import { json } from '@sveltejs/kit';
import { feedQuery, gridMedia } from '$lib/server/feed';
import type { RequestHandler } from './$types';

/** Every ready photo/video (newest first) in one response, for the grid: ?day=YYYY-MM-DD · ?person=<userId> */
export const GET: RequestHandler = async ({ url }) => {
	const { day, person } = feedQuery(url);
	return json({ media: await gridMedia({ day, person }) });
};
