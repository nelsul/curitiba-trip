import { error, redirect, type Handle } from '@sveltejs/kit';
import { SESSION_COOKIE, authenticate, bearerToken } from '$lib/server/auth';
import { GUEST_COOKIE, authenticateGuest, guestAllowed } from '$lib/server/guest';

const PUBLIC = ['/login', '/dev-login', '/visitante', '/api/auth/people', '/api/auth/code', '/api/auth/verify'];

export const handle: Handle = async ({ event, resolve }) => {
	// The iOS app sends `Authorization: Bearer <token>`; browsers send the session cookie.
	const bearer = bearerToken(event.request.headers.get('authorization'));
	const auth = await authenticate(bearer ?? event.cookies.get(SESSION_COOKIE));
	event.locals.user = auth?.user ?? null;
	event.locals.session = auth ? { id: auth.sessionId, kind: auth.kind } : null;

	const path = event.url.pathname;
	// a visitor (browser only): reads the Diário while their code lasts, and nothing else
	event.locals.guest = !event.locals.user && !bearer ? await authenticateGuest(event.cookies.get(GUEST_COOKIE)) : null;
	if (event.locals.guest) {
		if (!guestAllowed(event.request.method, path, path.startsWith('/api/'))) {
			if (path.startsWith('/api/')) error(403, 'Visitantes só podem ver o diário.');
			redirect(303, '/');
		}
		return resolve(event);
	}
	if (!event.locals.user && event.cookies.get(GUEST_COOKIE) && !PUBLIC.some((p) => path === p || path.startsWith(p + '/'))) {
		// the visit is over (the code expired or was ended)
		event.cookies.delete(GUEST_COOKIE, { path: '/' });
		if (path.startsWith('/api/')) error(401, 'A visita acabou. Peça um novo código.');
		redirect(303, '/visitante?fim=1');
	}
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
