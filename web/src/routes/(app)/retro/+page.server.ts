import { feed, people } from '$lib/server/feed';
import { retro } from '$lib/server/retro';
import type { FeedMedia } from '$lib/types';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, depends }) => {
	depends('app:retro');
	const [r, persons] = await Promise.all([retro(), people()]);
	// admins pick from every photo/video
	const all = locals.user!.isAdmin
		? (await feed()).filter((i): i is FeedMedia => i.type === 'media' && i.status === 'ready').sort((a, b) => b.at.localeCompare(a.at))
		: [];
	return { ...r, persons, all };
};
