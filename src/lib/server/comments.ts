import { error, fail } from '@sveltejs/kit';
import { and, asc, eq } from 'drizzle-orm';
import { comments, db, users } from './db';
import { clip } from './validate';

export async function listComments(target: { mediaId: string } | { checkinId: string }) {
	const where = 'mediaId' in target ? eq(comments.mediaId, target.mediaId) : eq(comments.checkinId, target.checkinId);
	const rows = await db()
		.select({ id: comments.id, body: comments.body, at: comments.createdAt, userId: users.id, name: users.name, color: users.color })
		.from(comments)
		.innerJoin(users, eq(users.id, comments.userId))
		.where(where)
		.orderBy(asc(comments.createdAt));
	return rows.map((r) => ({ ...r, at: r.at.toISOString() }));
}

export async function addComment(request: Request, userId: string, target: { mediaId: string } | { checkinId: string }) {
	const body = clip((await request.formData()).get('body'), 2000);
	if (!body) return fail(400, { commentError: 'Escreva alguma coisa.' });
	await db().insert(comments).values({ userId, body, ...target });
	return { commented: true };
}

export async function deleteComment(request: Request, userId: string) {
	const id = String((await request.formData()).get('id') ?? '');
	if (!/^[0-9a-f-]{36}$/.test(id)) error(400, 'Comentário inválido');
	await db().delete(comments).where(and(eq(comments.id, id), eq(comments.userId, userId)));
	return { deleted: true };
}
