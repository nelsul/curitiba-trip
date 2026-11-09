import { json } from '@sveltejs/kit';
import { payAll } from '$lib/server/splits';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** `{ payerId }`: "Paguei tudo", every part I still owe that person is marked paid → `{ parts, totalCents }`. */
export const POST: RequestHandler = async ({ request, locals }) => {
	const { payerId } = await body<{ payerId?: unknown }>(request);
	return json(await payAll(locals.user!, payerId));
};
