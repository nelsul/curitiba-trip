import { error, json as reply } from '@sveltejs/kit';
import { eq } from 'drizzle-orm';
import { verifyCode } from '$lib/server/auth';
import { db, users } from '$lib/server/db';
import { MIN_APP_VERSION, toMe } from '$lib/server/me';
import { clip, json } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** Public: checks the code and returns a device token for `Authorization: Bearer` (iOS app). */
export const POST: RequestHandler = async ({ request }) => {
	const b = await json<{ userId?: string; code?: string; deviceName?: string }>(request);
	const r = await verifyCode(String(b.userId ?? ''), String(b.code ?? ''), {
		kind: 'device',
		deviceName: clip(b.deviceName, 60) || 'iPhone'
	});
	if (!r.ok) error(400, r.error);
	const [u] = await db().select().from(users).where(eq(users.id, String(b.userId)));
	return reply({ token: r.token, user: await toMe(u), minAppVersion: MIN_APP_VERSION });
};
