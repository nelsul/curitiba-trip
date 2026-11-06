import { error } from '@sveltejs/kit';
import { and, eq } from 'drizzle-orm';
import { db, media } from './db';

export async function ownedUpload(id: string, userId: string) {
	if (!/^[0-9a-f-]{36}$/.test(id)) error(404, 'Não encontrado');
	const [m] = await db().select().from(media).where(and(eq(media.id, id), eq(media.userId, userId)));
	if (!m) error(404, 'Não encontrado');
	return m;
}
