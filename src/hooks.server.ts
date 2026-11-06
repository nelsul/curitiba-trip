import { error, redirect, type Handle } from '@sveltejs/kit';
import { SESSION_COOKIE, userFromToken } from '$lib/server/auth';

const PUBLIC = ['/login', '/dev-login'];

export const handle: Handle = async ({ event, resolve }) => {
	event.locals.user = await userFromToken(event.cookies.get(SESSION_COOKIE));
	const path = event.url.pathname;
	if (!event.locals.user && !PUBLIC.some((p) => path === p || path.startsWith(p + '/'))) {
		if (path.startsWith('/api/')) error(401, 'Faça login de novo.');
		redirect(303, `/login${path === '/' ? '' : `?para=${encodeURIComponent(path)}`}`);
	}
	if (path.startsWith('/admin') && !event.locals.user?.isAdmin) error(403, 'Só para administradores.');
	return resolve(event);
};
