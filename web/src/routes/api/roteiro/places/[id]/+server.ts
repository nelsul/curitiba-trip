import { json } from '@sveltejs/kit';
import { deletePlace, updatePlace } from '$lib/server/roteiro';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** Anyone can edit the shared places (same fields as POST /api/roteiro/places). */
export const PATCH: RequestHandler = async ({ params, request }) => {
	await updatePlace(params.id, await body(request));
	return json({ ok: true });
};

/** Removes the place and its photos; itinerary stops that used it keep its name as text. */
export const DELETE: RequestHandler = async ({ params }) => {
	await deletePlace(params.id);
	return json({ ok: true });
};
