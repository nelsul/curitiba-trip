import { feed, people } from '$lib/server/feed';
import type { FeedMedia } from '$lib/types';
import type { PageServerLoad } from './$types';

/** Every photo and video (no check-ins), newest first, for the full-screen Galeria. */
export const load: PageServerLoad = async ({ depends }) => {
	depends('app:feed');
	const [items, persons] = await Promise.all([feed(), people()]);
	const media = items
		.filter((i): i is FeedMedia => i.type === 'media' && i.status === 'ready' && !!(i.image || i.video))
		.sort((a, b) => b.at.localeCompare(a.at));
	return { media, persons };
};
