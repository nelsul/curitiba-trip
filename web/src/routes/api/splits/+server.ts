import { json } from '@sveltejs/kit';
import { createSplit, listSplits } from '$lib/server/splits';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** Every cotinha (newest first) and `myPix`, the Pix key I used last. */
export const GET: RequestHandler = async ({ locals }) => json(await listSplits(locals.user!.id));

/** `{ title, totalCents, pixKey?, note?, participants: [userId] }` (equal parts) or `shares: [{ userId, amountCents }]`. I'm the payer. */
export const POST: RequestHandler = async ({ request, locals }) =>
	json({ id: await createSplit(locals.user!.id, await body(request)) }, { status: 201 });
