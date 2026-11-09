import { gridMedia } from '$lib/server/feed';
import { retro } from '$lib/server/retro';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, depends }) => {
	depends('app:retro');
	const r = await retro();
	// admins pick from every photo/video
	const all = locals.user!.isAdmin ? await gridMedia({}) : [];
	return { ...r, all };
};
