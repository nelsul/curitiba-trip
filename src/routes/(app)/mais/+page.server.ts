import { redirect } from '@sveltejs/kit';
import { signOut } from '$lib/server/auth';
import type { Actions } from './$types';

export const actions: Actions = {
	sair: async ({ cookies }) => {
		await signOut(cookies);
		redirect(303, '/login');
	}
};
