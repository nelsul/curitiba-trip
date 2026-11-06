import { fail, redirect } from '@sveltejs/kit';
import { requestCode, setSessionCookie, verifyCode } from '$lib/server/auth';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = ({ locals }) => {
	if (locals.user) redirect(303, '/');
};

export const actions: Actions = {
	enviar: async ({ request }) => {
		const email = String((await request.formData()).get('email') ?? '');
		const r = await requestCode(email);
		if (!r.ok) return fail(400, { step: 'email' as const, email, error: r.error });
		return { step: 'code' as const, email };
	},
	verificar: async ({ request, cookies, url }) => {
		const f = await request.formData();
		const email = String(f.get('email') ?? '');
		const r = await verifyCode(email, String(f.get('code') ?? ''));
		if (!r.ok) return fail(400, { step: 'code' as const, email, error: r.error });
		setSessionCookie(cookies, r.token);
		const to = url.searchParams.get('para');
		redirect(303, to && to.startsWith('/') && !to.startsWith('//') ? to : '/');
	}
};
