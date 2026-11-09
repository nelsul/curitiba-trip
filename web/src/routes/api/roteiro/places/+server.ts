import { json } from '@sveltejs/kit';
import { createPlace } from '$lib/server/roteiro';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** New place: { name, category, lat, lng, address?, hours?, price?, priceLevel?, description?, link? } → { id } */
export const POST: RequestHandler = async ({ request, locals }) =>
	json({ id: await createPlace(await body(request), locals.user!.id) }, { status: 201 });
