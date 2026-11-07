import { error, json } from '@sveltejs/kit';
import { and, eq, isNull } from 'drizzle-orm';
import { checkins, db } from '$lib/server/db';
import { mediaUrl } from '$lib/server/r2';
import { deleteObject, putImage, sniffImage } from '$lib/server/images';
import type { RequestHandler } from './$types';

const MAX_BYTES = 1536 * 1024; // 1080x720 WebP is usually 100–400 KB

/**
 * Stores the map picture generated in the browser. The owner can always replace it; anyone signed in
 * may fill a check-in that has none yet (older check-ins get their picture the first time someone sees them).
 */
export const PUT: RequestHandler = async ({ params, request, locals }) => {
	if (!/^[0-9a-f-]{36}$/.test(params.id)) error(404, 'Não encontrado');
	const [c] = await db().select().from(checkins).where(eq(checkins.id, params.id));
	if (!c) error(404, 'Não encontrado');
	const owner = c.userId === locals.user!.id;
	if (!owner && c.snapshotKey) return json({ snapshot: await mediaUrl(c.snapshotKey) }); // already filled

	const body = new Uint8Array(await request.arrayBuffer());
	if (body.length === 0 || body.length > MAX_BYTES) error(413, 'Imagem inválida.');
	const kind = sniffImage(body);
	if (!kind) error(415, 'Formato não suportado.');

	const key = await putImage(`checkins/${c.id}`, body, kind);
	const where = owner ? eq(checkins.id, c.id) : and(eq(checkins.id, c.id), isNull(checkins.snapshotKey));
	const updated = await db().update(checkins).set({ snapshotKey: key }).where(where).returning({ id: checkins.id });
	if (!updated.length) {
		await deleteObject(key); // someone else filled it first
		const [now] = await db().select({ k: checkins.snapshotKey }).from(checkins).where(eq(checkins.id, c.id));
		return json({ snapshot: await mediaUrl(now?.k) });
	}
	if (owner) await deleteObject(c.snapshotKey);
	return json({ snapshot: await mediaUrl(key) });
};
