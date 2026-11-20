import { retro } from '$lib/server/retro';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ depends }) => {
	depends('app:retro');
	return retro();
};
