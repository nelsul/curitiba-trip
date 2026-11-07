import { error, json as reply } from '@sveltejs/kit';
import { requestCode } from '$lib/server/auth';
import { json } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** Public: emails a 6-digit code to the picked person. Throttled to one email per minute per person. */
export const POST: RequestHandler = async ({ request }) => {
	const { userId } = await json<{ userId?: string }>(request);
	const r = await requestCode(String(userId ?? ''));
	if (!r.ok) error(400, r.error);
	return reply({ maskedEmail: r.maskedEmail });
};
