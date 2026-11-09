import { people } from '$lib/server/feed';
import { listSplits } from '$lib/server/splits';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, depends }) => {
	depends('app:cotinha');
	const [list, persons] = await Promise.all([listSplits(locals.user!.id), people()]);
	return { ...list, persons };
};
