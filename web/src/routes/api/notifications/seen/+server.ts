import { json } from '@sveltejs/kit';
import { markNotificationsSeen } from '$lib/server/notifications';
import type { RequestHandler } from './$types';

/** The notifications page was opened: everything until now is read. */
export const POST: RequestHandler = async ({ locals }) => {
	await markNotificationsSeen(locals.user!.id);
	return json({ ok: true });
};
