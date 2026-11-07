import { error, json } from '@sveltejs/kit';
import { feedUnsigned, signItems } from '$lib/server/feed';
import { groupPosts, isOlderThan, postCursor, type Post } from '$lib/feed-group';
import type { RequestHandler } from './$types';

/**
 * Newest-first posts (carousels already grouped, like the web feed).
 * ?limit=1..50 (default 20) · ?before=<nextCursor> · ?day=YYYY-MM-DD · ?person=<userId>
 * `days` lists every day that has posts (ignoring the filters), for the day chips.
 */
export const GET: RequestHandler = async ({ url }) => {
	const limit = Math.min(50, Math.max(1, Number(url.searchParams.get('limit')) || 20));
	const before = url.searchParams.get('before');
	const day = url.searchParams.get('day');
	const person = url.searchParams.get('person');
	if (day && !/^\d{4}-\d{2}-\d{2}$/.test(day)) error(400, 'Dia inválido');
	if (before && !/^\d{4}-\d{2}-\d{2}T[\d:.]+Z\|[mc][0-9a-f-]{36}$/.test(before)) error(400, 'Cursor inválido');

	const { items, keys } = await feedUnsigned();
	const filtered = items.filter((i) => (!day || i.day === day) && (!person || i.userId === person));
	const all = groupPosts(filtered);
	const start = before ? all.filter((p) => isOlderThan(p, before)) : all;
	const page = start.slice(0, limit);

	const posts: Post[] = await Promise.all(
		page.map(async (p) =>
			p.type === 'media' ? { ...p, items: await signItems(p.items, keys) } : { ...p, item: (await signItems([p.item], keys))[0] }
		)
	);
	const days = [...new Set(items.map((i) => i.day))].sort();
	return json({ posts, nextCursor: start.length > limit ? postCursor(page.at(-1)!) : null, days });
};
