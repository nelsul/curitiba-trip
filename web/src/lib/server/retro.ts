import { feedUnsigned, signItems } from './feed';
import { WEDDING_AT } from '$lib/trip';
import type { FeedMedia } from '$lib/types';

/** The Retrospectiva: every photo/video someone starred, oldest first (each says who starred it in `favs`). */
export async function retro() {
	const { items, keys } = await feedUnsigned();
	const starred = items.filter((i): i is FeedMedia => i.type === 'media' && i.status === 'ready' && i.favs.length > 0);
	return { weddingAt: new Date(WEDDING_AT).toISOString(), items: await signItems(starred, keys) };
}
