import { eq, inArray } from 'drizzle-orm';
import { checkins, db, media, users } from './db';
import { activityBetween } from './activity';
import { mediaUrl } from './r2';
import { brl } from '$lib/money';
import { dayKey } from '$lib/format';

export type NoteKind = 'post' | 'checkin' | 'comment' | 'like' | 'mention' | 'split' | 'paid';

/** One line in the notifications page (the texts are ready to show, the same on the website and in the apps). */
export type Note = {
	id: string;
	kind: NoteKind;
	/** who did it */
	userId: string;
	text: string;
	/** comment text, check-in note, cotinha amount… ('' when none) */
	body: string;
	at: string;
	/** where a tap goes: a post, a check-in, or the Cotinha */
	mediaId: string | null;
	checkinId: string | null;
	cotinha: boolean;
	/** a small picture of the post */
	image: string | null;
	unread: boolean;
};

const WINDOW_MS = 14 * 86_400_000;

const plural = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`;

/** The last two weeks of what other people did that concerns `me`, newest first (at most 150). */
export async function notifications(me: string): Promise<{ items: Note[]; unread: number }> {
	const now = new Date();
	const [a, people, [u]] = await Promise.all([
		activityBetween(me, new Date(now.getTime() - WINDOW_MS), now),
		db().select({ id: users.id, name: users.name }).from(users),
		db().select({ seen: users.notificationsSeenAt }).from(users).where(eq(users.id, me))
	]);
	const name = (id: string) => people.find((p) => p.id === id)?.name ?? 'Alguém';
	const notes: Omit<Note, 'image' | 'unread'>[] = [];

	// posts: one line per person per day ("Bruna postou 3 fotos e 1 vídeo")
	const posts = new Map<string, { userId: string; photos: number; videos: number; at: Date; firstId: string }>();
	for (const m of a.newMedia) {
		const k = `${m.userId}|${dayKey(m.at)}`;
		const p = posts.get(k) ?? posts.set(k, { userId: m.userId, photos: 0, videos: 0, at: m.at, firstId: m.id }).get(k)!;
		if (m.kind === 'video') p.videos++;
		else p.photos++;
		if (m.at > p.at) p.at = m.at;
	}
	for (const [k, p] of posts) {
		const what = [p.photos ? plural(p.photos, 'foto', 'fotos') : '', p.videos ? plural(p.videos, 'vídeo', 'vídeos') : ''].filter(Boolean).join(' e ');
		notes.push({ id: `post-${k}`, kind: 'post', userId: p.userId, text: `${name(p.userId)} postou ${what}`, body: '', at: p.at.toISOString(), mediaId: p.firstId, checkinId: null, cotinha: false });
	}
	for (const c of a.newCheckins) {
		notes.push({ id: `checkin-${c.id}`, kind: 'checkin', userId: c.userId, text: `${name(c.userId)} fez check-in`, body: c.note, at: c.at.toISOString(), mediaId: null, checkinId: c.id, cotinha: false });
	}
	for (const c of a.newComments) {
		notes.push({ id: `comment-${c.id}`, kind: 'comment', userId: c.userId, text: `${name(c.userId)} comentou no seu post`, body: c.body, at: c.at.toISOString(), mediaId: c.mediaId, checkinId: c.checkinId, cotinha: false });
	}
	const commented = new Set(a.newComments.map((c) => c.id));
	for (const c of a.mentions) {
		if (commented.has(c.id)) continue;
		notes.push({ id: `mention-${c.id}`, kind: 'mention', userId: c.userId, text: `${name(c.userId)} marcou você num comentário`, body: c.body, at: c.at.toISOString(), mediaId: c.mediaId, checkinId: c.checkinId, cotinha: false });
	}
	// likes: one line per person per day
	const liked = new Map<string, { userId: string; n: number; at: Date; mediaId: string | null; checkinId: string | null }>();
	for (const l of a.newLikes) {
		const k = `${l.userId}|${dayKey(l.at)}`;
		const x = liked.get(k) ?? liked.set(k, { userId: l.userId, n: 0, at: l.at, mediaId: l.mediaId, checkinId: l.checkinId }).get(k)!;
		x.n++;
		if (l.at >= x.at) Object.assign(x, { at: l.at, mediaId: l.mediaId, checkinId: l.checkinId });
	}
	for (const [k, l] of liked) {
		notes.push({ id: `like-${k}`, kind: 'like', userId: l.userId, text: `${name(l.userId)} curtiu ${l.n === 1 ? 'seu post' : `${l.n} posts seus`}`, body: '', at: l.at.toISOString(), mediaId: l.mediaId, checkinId: l.checkinId, cotinha: false });
	}
	for (const s of a.splitEvents) {
		const text = s.kind === 'reminder' ? `${name(s.payerId)} está cobrando: ${s.title}` : `${name(s.payerId)} criou uma cotinha: ${s.title}`;
		notes.push({ id: `split-${s.id}-${s.at}`, kind: 'split', userId: s.payerId, text, body: `Sua parte: ${brl(s.amountCents)}`, at: s.at, mediaId: null, checkinId: null, cotinha: true });
	}
	for (const p of a.paidToMe) {
		notes.push({ id: `paid-${p.id}-${p.userId}`, kind: 'paid', userId: p.userId, text: `${name(p.userId)} pagou ${brl(p.amountCents)}`, body: `Cotinha: ${p.title}`, at: p.at!.toISOString(), mediaId: null, checkinId: null, cotinha: true });
	}
	notes.sort((x, y) => y.at.localeCompare(x.at));
	const list = notes.slice(0, 150);

	// small pictures: the photo/video, or the check-in's map
	const mediaIds = [...new Set(list.map((n) => n.mediaId).filter((x): x is string => !!x))];
	const checkinIds = [...new Set(list.map((n) => n.checkinId).filter((x): x is string => !!x))];
	const [mRows, cRows] = await Promise.all([
		mediaIds.length ? db().select({ id: media.id, key: media.thumbKey, preview: media.previewKey }).from(media).where(inArray(media.id, mediaIds)) : [],
		checkinIds.length ? db().select({ id: checkins.id, key: checkins.snapshotKey }).from(checkins).where(inArray(checkins.id, checkinIds)) : []
	]);
	const pics = new Map<string, string | null>();
	await Promise.all([
		...mRows.map(async (r) => pics.set(r.id, await mediaUrl(r.key ?? r.preview))),
		...cRows.map(async (r) => pics.set(r.id, await mediaUrl(r.key)))
	]);

	// never opened: only the last two days count as new
	const seen = (u?.seen ?? new Date(now.getTime() - 2 * 86_400_000)).toISOString();
	const items = list.map((n) => ({ ...n, image: pics.get(n.mediaId ?? n.checkinId ?? '') ?? null, unread: n.at > seen }));
	return { items, unread: items.filter((n) => n.unread).length };
}

export async function markNotificationsSeen(me: string) {
	await db().update(users).set({ notificationsSeenAt: new Date() }).where(eq(users.id, me));
}
