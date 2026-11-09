import { json } from '@sveltejs/kit';
import { deleteDay, saveDay } from '$lib/server/roteiro';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/**
 * Creates or replaces a day: { title, who, lead, wedding, stops: [{ time, placeId | label, transport, note }] }.
 * The stops are saved in the order sent.
 */
export const PUT: RequestHandler = async ({ params, request, locals }) => {
	await saveDay(params.date, await body(request), locals.user!.id);
	return json({ ok: true });
};

export const DELETE: RequestHandler = async ({ params }) => {
	await deleteDay(params.date);
	return json({ ok: true });
};
