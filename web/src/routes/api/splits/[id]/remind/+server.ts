import { json } from '@sveltejs/kit';
import { remind } from '$lib/server/splits';
import type { RequestHandler } from './$types';

/** Who paid asks everyone who hasn't paid yet (they get a notification). */
export const POST: RequestHandler = async ({ params, locals }) => {
	await remind(params.id, locals.user!);
	return json({ ok: true });
};
