import { dev } from '$app/environment';
import { error, redirect } from '@sveltejs/kit';
import { createHash, randomBytes } from 'node:crypto';
import { db, sessions, users } from '$lib/server/db';
import { setSessionCookie } from '$lib/server/auth';
import type { RequestHandler } from './$types';

/** Local development only: sign in as a throwaway test user without email. 404 in production builds. */
export const GET: RequestHandler = async ({ cookies, url }) => {
	if (!dev) error(404, 'Não encontrado');
	const [u] = await db()
		.insert(users)
		.values({ name: 'Teste', email: 'claude-local@example.test', color: '#E8A33D' })
		.onConflictDoUpdate({ target: users.email, set: { name: 'Teste' } })
		.returning();
	const token = randomBytes(32).toString('base64url');
	await db().insert(sessions).values({
		id: createHash('sha256').update(token).digest('hex'),
		userId: u.id,
		expiresAt: new Date(Date.now() + 86_400_000)
	});
	setSessionCookie(cookies, token);
	redirect(303, url.searchParams.get('para') ?? '/');
};
