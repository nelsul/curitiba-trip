import { error } from '@sveltejs/kit';
import { asc, inArray } from 'drizzle-orm';
import { db, media, retroItems } from './db';
import { feedUnsigned, signItems } from './feed';
import { WEDDING_AT } from '$lib/trip';
import type { FeedMedia } from '$lib/types';

/** The Retrospectiva: the photos/videos the admin picked, in their order, and when the wedding starts. */
export async function retro() {
	const order = await db().select().from(retroItems).orderBy(asc(retroItems.position));
	const { items, keys } = await feedUnsigned();
	const byId = new Map(items.filter((i): i is FeedMedia => i.type === 'media' && i.status === 'ready').map((i) => [i.id, i]));
	const picked = order.map((o) => byId.get(o.mediaId)).filter((m): m is FeedMedia => !!m);
	return { weddingAt: new Date(WEDDING_AT).toISOString(), items: await signItems(picked, keys) };
}

/** Admin: replaces the whole list, in this order. */
export async function setRetro(ids: unknown) {
	if (!Array.isArray(ids) || ids.some((i) => typeof i !== 'string' || !/^[0-9a-f-]{36}$/.test(i))) error(400, 'Lista inválida.');
	const unique = [...new Set(ids as string[])].slice(0, 300);
	const found = unique.length ? await db().select({ id: media.id }).from(media).where(inArray(media.id, unique)) : [];
	const ok = new Set(found.map((f) => f.id));
	await db().transaction(async (tx) => {
		await tx.delete(retroItems);
		const rows = unique.filter((i) => ok.has(i)).map((mediaId, position) => ({ mediaId, position }));
		if (rows.length) await tx.insert(retroItems).values(rows);
	});
}
