import { json } from '@sveltejs/kit';
import { and, desc, eq } from 'drizzle-orm';
import { db, sessions } from '$lib/server/db';
import type { RequestHandler } from './$types';

/** My signed-in iOS devices. `id` is a short handle of the session hash (never the token). */
export const GET: RequestHandler = async ({ locals }) => {
	const rows = await db()
		.select({ id: sessions.id, deviceName: sessions.deviceName, lastUsedAt: sessions.lastUsedAt, createdAt: sessions.createdAt })
		.from(sessions)
		.where(and(eq(sessions.userId, locals.user!.id), eq(sessions.kind, 'device')))
		.orderBy(desc(sessions.lastUsedAt));
	return json(
		rows.map((r) => ({
			id: r.id.slice(0, 16),
			deviceName: r.deviceName,
			lastUsedAt: r.lastUsedAt?.toISOString() ?? null,
			createdAt: r.createdAt.toISOString(),
			current: r.id === locals.session?.id
		}))
	);
};
