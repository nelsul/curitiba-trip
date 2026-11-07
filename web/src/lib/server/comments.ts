import { error, fail } from '@sveltejs/kit';
import { and, asc, eq } from 'drizzle-orm';
import { comments, db, users } from './db';
import { clip } from './validate';
import { mediaUrl } from './r2';

export async function listComments(target: { mediaId: string } | { checkinId: string }) {
	const where = 'mediaId' in target ? eq(comments.mediaId, target.mediaId) : eq(comments.checkinId, target.checkinId);
	const rows = await db()
		.select({ id: comments.id, body: comments.body, at: comments.createdAt, userId: users.id, name: users.name, color: users.color, avatarKey: users.avatarKey })
		.from(comments)
		.innerJoin(users, eq(users.id, comments.userId))
		.where(where)
		.orderBy(asc(comments.createdAt));
	return Promise.all(rows.map(async ({ avatarKey, ...r }) => ({ ...r, photo: await mediaUrl(avatarKey), at: r.at.toISOString() })));
}

type Target = { mediaId: string } | { checkinId: string };

/** Adds a comment; returns null when the text is empty. */
export async function createComment(userId: string, target: Target, text: unknown) {
	const body = clip(text, 2000);
	if (!body) return null;
	const [c] = await db().insert(comments).values({ userId, body, ...target }).returning({ id: comments.id });
	return c.id;
}

/** Deletes one of my comments; returns false if it wasn't mine (or doesn't exist). */
export async function removeComment(id: string, userId: string) {
	if (!/^[0-9a-f-]{36}$/.test(id)) error(400, 'Comentário inválido');
	const gone = await db().delete(comments).where(and(eq(comments.id, id), eq(comments.userId, userId))).returning({ id: comments.id });
	return gone.length > 0;
}

// Form-action helpers for the web pages
export async function addComment(request: Request, userId: string, target: Target) {
	const id = await createComment(userId, target, (await request.formData()).get('body'));
	if (!id) return fail(400, { commentError: 'Escreva alguma coisa.' });
	return { commented: true };
}

export async function deleteComment(request: Request, userId: string) {
	await removeComment(String((await request.formData()).get('id') ?? ''), userId);
	return { deleted: true };
}
