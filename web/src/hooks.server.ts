import { error, redirect, type Handle } from '@sveltejs/kit';
import { SESSION_COOKIE, authenticate, bearerToken } from '$lib/server/auth';

const PUBLIC = ['/login', '/dev-login', '/api/auth/people', '/api/auth/code', '/api/auth/verify'];

export const handle: Handle = async ({ event, resolve }) => {
	// The iOS app sends `Authorization: Bearer <token>`; browsers send the session cookie.
	const bearer = bearerToken(event.request.headers.get('authorization'));
	const auth = await authenticate(bearer ?? event.cookies.get(SESSION_COOKIE));
	event.locals.user = auth?.user ?? null;
	event.locals.session = auth ? { id: auth.sessionId, kind: auth.kind } : null;

	const path = event.url.pathname;
	if (!event.locals.user && !PUBLIC.some((p) => path === p || path.startsWith(p + '/'))) {
		if (path.startsWith('/api/') || bearer) error(401, 'Faça login de novo.');
		redirect(303, `/login${path === '/' ? '' : `?para=${encodeURIComponent(path)}`}`);
	}
	if ((path.startsWith('/admin') || path.startsWith('/api/admin')) && !event.locals.user?.isAdmin) error(403, 'Só para administradores.');
	// Roteiro: only admins change the places and the days (everyone reads them and ticks "Fomos!")
	if (
		event.request.method !== 'GET' &&
		(path.startsWith('/api/roteiro/places') || path.startsWith('/api/roteiro/days/')) &&
		!event.locals.user?.isAdmin
	)
		error(403, 'Só administradores mudam o roteiro.');
	return resolve(event);
};
