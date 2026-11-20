import { json } from '@sveltejs/kit';
import { feedQuery, gridMedia } from '$lib/server/feed';
import { forGuestItems } from '$lib/server/guest';
import type { RequestHandler } from './$types';

/** Every ready photo/video (newest first) in one response, for the grid: ?day=YYYY-MM-DD · ?person=<userId> */
export const GET: RequestHandler = async ({ url, locals }) => {
	const { day, person } = feedQuery(url);
	const media = await gridMedia({ day, person });
	return json({ media: locals.guest ? forGuestItems(media) : media });
};
