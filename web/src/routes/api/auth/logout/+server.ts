import { json } from '@sveltejs/kit';
import { revokeSession } from '$lib/server/auth';
import type { RequestHandler } from './$types';

/** Ends the current session (the token used for this request stops working). */
export const POST: RequestHandler = async ({ locals }) => {
	if (locals.session) await revokeSession(locals.session.id);
	return json({ ok: true });
};
