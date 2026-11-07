import { fail, redirect } from '@sveltejs/kit';
import { requestCode, setSessionCookie, verifyCode } from '$lib/server/auth';
import { people } from '$lib/server/feed';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals }) => {
	if (locals.user) redirect(303, '/');
	return { persons: await people() };
};

export const actions: Actions = {
	enviar: async ({ request }) => {
		const userId = String((await request.formData()).get('userId') ?? '');
		const r = await requestCode(userId);
		if (!r.ok) return fail(400, { step: 'pick' as const, error: r.error });
		return { step: 'code' as const, userId, maskedEmail: r.maskedEmail };
	},
	verificar: async ({ request, cookies, url }) => {
		const f = await request.formData();
		const userId = String(f.get('userId') ?? '');
		const maskedEmail = String(f.get('maskedEmail') ?? '');
		const r = await verifyCode(userId, String(f.get('code') ?? ''));
		if (!r.ok) return fail(400, { step: 'code' as const, userId, maskedEmail, error: r.error });
		setSessionCookie(cookies, r.token);
		const to = url.searchParams.get('para');
		redirect(303, to && to.startsWith('/') && !to.startsWith('//') ? to : '/');
	}
};
