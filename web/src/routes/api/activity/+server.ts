import { error, json } from '@sveltejs/kit';
import { activityBetween } from '$lib/server/activity';
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

	const { byPerson, newCheckins, newComments, newLikes, mentions, splitEvents, paidToMe } = await activityBetween(me, from, now);
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
