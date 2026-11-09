import { json } from '@sveltejs/kit';
import { notifications } from '$lib/server/notifications';
import type { RequestHandler } from './$types';

/**
 * The notifications page: `{ items: [{ id, kind, userId, text, body, at, mediaId, checkinId, cotinha, image, unread }], unread }`,
 * the last two weeks, newest first. `?count=1` returns only `{ unread }` (for the bell's badge).
 */
export const GET: RequestHandler = async ({ url, locals }) => {
	const r = await notifications(locals.user!.id);
	return json(url.searchParams.get('count') ? { unread: r.unread } : r);
};
