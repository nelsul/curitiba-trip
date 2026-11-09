import { json } from '@sveltejs/kit';
import { setPaid } from '$lib/server/splits';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** `{ paid: boolean, userId? }`: my own part, or anyone's when I'm who paid. */
export const POST: RequestHandler = async ({ params, request, locals }) => {
	await setPaid(params.id, locals.user!, await body(request));
	return json({ ok: true });
};
