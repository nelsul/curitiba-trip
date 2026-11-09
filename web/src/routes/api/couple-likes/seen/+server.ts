import { json } from '@sveltejs/kit';
import { markCoupleLikesSeen } from '$lib/server/couple';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** `{ upTo: likeId }`: the effect was shown; don't return these likes again. */
export const POST: RequestHandler = async ({ request, locals }) => {
	const { upTo } = await body<{ upTo?: unknown }>(request);
	await markCoupleLikesSeen(locals.user!.id, upTo);
	return json({ ok: true });
};
