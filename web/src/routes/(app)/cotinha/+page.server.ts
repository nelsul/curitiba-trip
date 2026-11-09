import { listSplits } from '$lib/server/splits';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, depends }) => {
	depends('app:cotinha');
	return listSplits(locals.user!.id);
};
