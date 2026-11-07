import type { FeedCheckin, FeedItem, FeedMedia } from './types';

/** Photos/videos by the same person on the same day, at most 30 min apart, become one carousel post. */
export const GROUP_GAP_MS = 30 * 60_000;

export type MediaPost = { type: 'media'; key: string; userId: string; day: string; at: string; items: FeedMedia[] };
export type CheckinPost = { type: 'checkin'; key: string; userId: string; day: string; at: string; item: FeedCheckin };
/** `at` is the newest moment in the post (used for ordering and the API cursor). */
export type Post = MediaPost | CheckinPost;

/**
 * Groups feed items into posts, newest post first. Carousel items keep their own (oldest → newest) order.
 * Shared by the web feed (in the browser) and GET /api/feed (on the server), so both group identically.
 */
export function groupPosts(items: FeedItem[]): Post[] {
	const asc = [...items].sort((a, b) => a.at.localeCompare(b.at) || a.id.localeCompare(b.id));
	const out: Post[] = [];
	for (const it of asc) {
		if (it.type === 'checkin') {
			out.push({ type: 'checkin', key: `c${it.id}`, userId: it.userId, day: it.day, at: it.at, item: it });
			continue;
		}
		const last = out.at(-1);
		if (
			last?.type === 'media' &&
			last.userId === it.userId &&
			last.day === it.day &&
			Date.parse(it.at) - Date.parse(last.at) <= GROUP_GAP_MS
		) {
			last.items.push(it);
			last.at = it.at;
		} else {
			out.push({ type: 'media', key: `m${it.id}`, userId: it.userId, day: it.day, at: it.at, items: [it] });
		}
	}
	return out.reverse();
}

/** Opaque cursor for "posts older than this one". */
export const postCursor = (p: Post) => `${p.at}|${p.key}`;

/** True when `p` comes after (is older than) the cursor in newest-first order. */
export function isOlderThan(p: Post, cursor: string) {
	const [at, key] = cursor.split('|');
	return p.at < at || (p.at === at && p.key < key);
}
