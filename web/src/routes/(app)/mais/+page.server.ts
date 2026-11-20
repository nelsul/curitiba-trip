import { redirect } from '@sveltejs/kit';
import { signOut } from '$lib/server/auth';
import { createGuestCode, endGuestCode, myGuestCodes } from '$lib/server/guest';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, depends }) => {
	depends('app:visitantes');
	return { guestCodes: await myGuestCodes(locals.user!.id) };
};

export const actions: Actions = {
	sair: async ({ cookies }) => {
		await signOut(cookies);
		redirect(303, '/login');
	},
	/** a new visitor code (shown once: only its hash is kept) */
	visitante: async ({ locals }) => ({ newCode: await createGuestCode(locals.user!.id) }),
	encerrarVisitante: async ({ request, locals }) => {
		await endGuestCode(String((await request.formData()).get('id') ?? ''), locals.user!);
		return { ended: true };
	}
};
