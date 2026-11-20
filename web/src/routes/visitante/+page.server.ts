import { fail, redirect } from '@sveltejs/kit';
import { GUEST_COOKIE, guestLogin, setGuestCookie } from '$lib/server/guest';
import type { Actions, PageServerLoad } from './$types';

/** Visitors type the code someone gave them; it opens the Diário for as long as the code lasts (2 hours). */
export const load: PageServerLoad = async ({ locals, url }) => {
	if (locals.user) redirect(303, '/');
	return {
		visiting: locals.guest ? { until: locals.guest.expiresAt.toISOString(), by: locals.guest.byName } : null,
		ended: url.searchParams.has('fim')
	};
};

export const actions: Actions = {
	entrar: async ({ request, cookies, getClientAddress }) => {
		const r = await guestLogin(String((await request.formData()).get('code') ?? ''), getClientAddress());
		if (!r.ok) return fail(400, { error: r.error });
		setGuestCookie(cookies, r.code, r.guest.expiresAt);
		redirect(303, '/');
	},
	sair: async ({ cookies }) => {
		cookies.delete(GUEST_COOKIE, { path: '/' });
		redirect(303, '/visitante');
	}
};
