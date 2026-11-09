import { error, json } from '@sveltejs/kit';
import { eq } from 'drizzle-orm';
import { db, users } from '$lib/server/db';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

/** Admin: `{ couple: 'noivo' | 'noiva' | null }` marks who is getting married. */
export const PUT: RequestHandler = async ({ params, request }) => {
	const { couple } = await body<{ couple?: unknown }>(request);
	if (couple !== null && couple !== 'noivo' && couple !== 'noiva') error(400, 'Valor inválido.');
	const done = await db().update(users).set({ couple }).where(eq(users.id, params.id)).returning({ id: users.id });
	if (!done.length) error(404, 'Pessoa não encontrada.');
	return json({ ok: true });
};
