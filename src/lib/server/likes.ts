import { asc, eq } from 'drizzle-orm';
import { db, likes } from './db';

export async function likersOf(target: { mediaId: string } | { checkinId: string }) {
	const col = 'mediaId' in target ? likes.mediaId : likes.checkinId;
	const rows = await db().select({ userId: likes.userId }).from(likes).where(eq(col, Object.values(target)[0])).orderBy(asc(likes.createdAt));
	return rows.map((r) => r.userId);
}
