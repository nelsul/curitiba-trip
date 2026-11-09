import { error, json } from '@sveltejs/kit';
import { and, asc, eq, gt, inArray, isNull, lte, ne, or } from 'drizzle-orm';
import type { AnyPgColumn } from 'drizzle-orm/pg-core';
import { checkins, commentMentions, comments, db, likes, media, splitShares, splits } from '$lib/server/db';
import type { RequestHandler } from './$types';

const MAX_WINDOW_MS = 7 * 86_400_000;

/**
 * What happened since `?since=<ISO time>` that I'd want a notification for (the iOS app shows these
 * as local notifications). Only other people's actions. Each call covers exactly (since, now], so passing the
 * returned `now` as the next `since` never repeats or skips anything.
 */
export const GET: RequestHandler = async ({ url, locals }) => {
	const me = locals.user!.id;
	const raw = url.searchParams.get('since');
	const since = raw ? new Date(raw) : new Date(Date.now() - 86_400_000);
	if (Number.isNaN(since.getTime())) error(400, 'Data inválida');
	const from = new Date(Math.max(since.getTime(), Date.now() - MAX_WINDOW_MS));
	const now = new Date();

	const [mine, myCheckins] = await Promise.all([
		db().select({ id: media.id }).from(media).where(eq(media.userId, me)),
		db().select({ id: checkins.id }).from(checkins).where(eq(checkins.userId, me))
	]);
	const myMedia = mine.map((r) => r.id), myCk = myCheckins.map((r) => r.id);
	const onMine = (col: { mediaId: AnyPgColumn; checkinId: AnyPgColumn }) =>
		or(myMedia.length ? inArray(col.mediaId, myMedia) : undefined, myCk.length ? inArray(col.checkinId, myCk) : undefined);

	const [newMedia, newCheckins, newComments, newLikes] = await Promise.all([
		db()
			.select({ id: media.id, userId: media.userId, kind: media.kind, at: media.createdAt })
			.from(media)
			.where(and(ne(media.userId, me), ne(media.status, 'uploading'), gt(media.createdAt, from), lte(media.createdAt, now)))
			.orderBy(asc(media.createdAt)),
		db()
			.select({ id: checkins.id, userId: checkins.userId, note: checkins.note, at: checkins.createdAt })
			.from(checkins)
			.where(and(ne(checkins.userId, me), gt(checkins.createdAt, from), lte(checkins.createdAt, now)))
			.orderBy(asc(checkins.createdAt)),
		myMedia.length || myCk.length
			? db()
					.select({ id: comments.id, userId: comments.userId, body: comments.body, mediaId: comments.mediaId, checkinId: comments.checkinId, at: comments.createdAt })
					.from(comments)
					.where(and(ne(comments.userId, me), gt(comments.createdAt, from), lte(comments.createdAt, now), onMine(comments)))
					.orderBy(asc(comments.createdAt))
			: [],
		myMedia.length || myCk.length
			? db()
					.select({ userId: likes.userId, mediaId: likes.mediaId, checkinId: likes.checkinId, at: likes.createdAt })
					.from(likes)
					.where(and(ne(likes.userId, me), gt(likes.createdAt, from), lte(likes.createdAt, now), onMine(likes)))
					.orderBy(asc(likes.createdAt))
			: []
	]);

	const [mentions, myShares, paidToMe] = await Promise.all([
		// comments that @mention me (anywhere, not only on my posts)
		db()
			.select({ id: comments.id, userId: comments.userId, body: comments.body, mediaId: comments.mediaId, checkinId: comments.checkinId, at: comments.createdAt })
			.from(commentMentions)
			.innerJoin(comments, eq(comments.id, commentMentions.commentId))
			.where(and(eq(commentMentions.userId, me), ne(comments.userId, me), gt(comments.createdAt, from), lte(comments.createdAt, now)))
			.orderBy(asc(comments.createdAt)),
		// cotinhas I still owe: new ones, and the payer's reminders
		db()
			.select({ id: splits.id, title: splits.title, payerId: splits.payerId, pixKey: splits.pixKey, amountCents: splitShares.amountCents, createdAt: splits.createdAt, remindedAt: splits.remindedAt })
			.from(splitShares)
			.innerJoin(splits, eq(splits.id, splitShares.splitId))
			.where(
				and(
					eq(splitShares.userId, me),
					ne(splits.payerId, me),
					isNull(splitShares.paidAt),
					or(and(gt(splits.createdAt, from), lte(splits.createdAt, now)), and(gt(splits.remindedAt, from), lte(splits.remindedAt, now)))
				)
			),
		// someone marked that they paid me
		db()
			.select({ id: splits.id, title: splits.title, userId: splitShares.userId, amountCents: splitShares.amountCents, at: splitShares.paidAt })
			.from(splitShares)
			.innerJoin(splits, eq(splits.id, splitShares.splitId))
			.where(and(eq(splits.payerId, me), ne(splitShares.userId, me), eq(splitShares.paidBy, splitShares.userId), gt(splitShares.paidAt, from), lte(splitShares.paidAt, now)))
	]);
	const inWindow = (d: Date | null) => !!d && d > from && d <= now;
	const splitEvents = myShares.map(({ createdAt, remindedAt, ...s }) => ({
		...s,
		kind: inWindow(remindedAt) ? ('reminder' as const) : ('new' as const),
		at: (inWindow(remindedAt) ? remindedAt! : createdAt).toISOString()
	}));

	// new posts summarized per person: "Bruna postou 5 fotos e 1 vídeo"
	const byPerson = new Map<string, { userId: string; photos: number; videos: number; latestAt: string; firstId: string }>();
	for (const m of newMedia) {
		const p = byPerson.get(m.userId) ?? { userId: m.userId, photos: 0, videos: 0, latestAt: '', firstId: m.id };
		if (m.kind === 'video') p.videos++;
		else p.photos++;
		p.latestAt = m.at.toISOString();
		byPerson.set(m.userId, p);
	}
	const iso = <T extends { at: Date }>(rows: T[]) => rows.map((r) => ({ ...r, at: r.at.toISOString() }));
	return json({
		now: now.toISOString(),
		since: from.toISOString(),
		posts: [...byPerson.values()],
		checkins: iso(newCheckins),
		comments: iso(newComments),
		likes: iso(newLikes),
		mentions: iso(mentions),
		splits: splitEvents,
		splitPaid: paidToMe.map((p) => ({ ...p, at: p.at!.toISOString() }))
	});
};
