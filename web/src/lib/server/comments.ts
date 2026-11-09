import { error, fail } from '@sveltejs/kit';
import { and, asc, eq } from 'drizzle-orm';
import { commentMentions, comments, db, users } from './db';
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
	const everyone = await db().select({ id: users.id, name: users.name }).from(users);
	const mentioned = mentionsIn(body, everyone).filter((id) => id !== userId);
	if (mentioned.length) await db().insert(commentMentions).values(mentioned.map((u) => ({ commentId: c.id, userId: u }))).onConflictDoNothing();
	return c.id;
}

const fold = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();

/**
 * Who a text @mentions: "@Ana Paula" (full name) or "@Ana" (first name, when only one person has it).
 * Accents and case don't matter. The apps insert the full name from the @ suggestions.
 */
export function mentionsIn(text: string, people: { id: string; name: string }[]) {
	const t = fold(text);
	const found = new Set<string>();
	const firsts = new Map<string, string[]>();
	for (const p of people) {
		const f = fold(p.name.split(/\s+/)[0]);
		firsts.set(f, [...(firsts.get(f) ?? []), p.id]);
	}
	const at = (name: string) => new RegExp(`(^|[^\\p{L}\\p{N}_])@${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?![\\p{L}\\p{N}_])`, 'u').test(t);
	for (const p of people) {
		if (at(fold(p.name))) found.add(p.id);
		else {
			const f = fold(p.name.split(/\s+/)[0]);
			if (firsts.get(f)?.length === 1 && at(f)) found.add(p.id);
		}
	}
	return [...found];
}

/** Deletes one of my comments (admins: anyone's); returns false if it wasn't mine (or doesn't exist). */
export async function removeComment(id: string, user: { id: string; isAdmin: boolean }) {
	if (!/^[0-9a-f-]{36}$/.test(id)) error(400, 'Comentário inválido');
	const gone = await db()
		.delete(comments)
		.where(user.isAdmin ? eq(comments.id, id) : and(eq(comments.id, id), eq(comments.userId, user.id)))
		.returning({ id: comments.id });
	return gone.length > 0;
}

// Form-action helpers for the web pages
export async function addComment(request: Request, userId: string, target: Target) {
	const id = await createComment(userId, target, (await request.formData()).get('body'));
	if (!id) return fail(400, { commentError: 'Escreva alguma coisa.' });
	return { commented: true };
}

export async function deleteComment(request: Request, user: { id: string; isAdmin: boolean }) {
	await removeComment(String((await request.formData()).get('id') ?? ''), user);
	return { deleted: true };
}
