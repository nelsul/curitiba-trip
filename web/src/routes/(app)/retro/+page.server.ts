import { retro } from '$lib/server/retro';
import { forGuestItems } from '$lib/server/guest';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ depends, locals }) => {
	depends('app:retro');
	const r = await retro();
	return locals.guest ? { ...r, items: forGuestItems(r.items) } : r;
};
