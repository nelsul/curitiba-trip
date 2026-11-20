import { env } from '$env/dynamic/private';
import { randomInt } from 'node:crypto';
import type { Cookies } from '@sveltejs/kit';
import { and, desc, eq, gt, lt } from 'drizzle-orm';
import { db, guestCodes, users } from './db';
import { sha256 } from './auth';

/**
 * Visitors: someone signed in makes a code in "Mais"; for 2 hours whoever has it can read the Diário (photos, videos,
 * the Retrospectiva), and nothing else: no map, itinerary, money, uploads, likes or comments. The browser keeps the
 * code itself in a cookie, so the visit ends when the code expires or its maker ends it.
 */
export const GUEST_COOKIE = 'visitante';
export const GUEST_HOURS = 2;
/** no 0/O, 1/I/L: easy to read aloud and type */
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const LENGTH = 8;

export type Guest = { codeId: string; by: string; byName: string; expiresAt: Date };

/** "abcd efgh" / "ABCD-EFGH" → "ABCDEFGH" */
const normalize = (raw: string) => raw.toUpperCase().replace(/[^A-Z0-9]/g, '');
/** "ABCDEFGH" → "ABCD-EFGH" (how it's shown) */
export const formatCode = (code: string) => `${code.slice(0, 4)}-${code.slice(4)}`;

export async function createGuestCode(userId: string) {
	const code = Array.from({ length: LENGTH }, () => ALPHABET[randomInt(ALPHABET.length)]).join('');
	const expiresAt = new Date(Date.now() + GUEST_HOURS * 3600_000);
	// expired codes are no longer useful to anyone
	await db().delete(guestCodes).where(lt(guestCodes.expiresAt, new Date()));
	const [row] = await db().insert(guestCodes).values({ codeHash: sha256(code), createdBy: userId, expiresAt }).returning({ id: guestCodes.id });
	return { id: row.id, code: formatCode(code), expiresAt: expiresAt.toISOString() };
}

/** My codes still running (newest first). The code itself isn't stored, so only when it ends is listed. */
export async function myGuestCodes(userId: string) {
	const rows = await db()
		.select({ id: guestCodes.id, expiresAt: guestCodes.expiresAt, createdAt: guestCodes.createdAt })
		.from(guestCodes)
		.where(and(eq(guestCodes.createdBy, userId), gt(guestCodes.expiresAt, new Date())))
		.orderBy(desc(guestCodes.createdAt));
	return rows.map((r) => ({ id: r.id, expiresAt: r.expiresAt.toISOString(), createdAt: r.createdAt.toISOString() }));
}

/** Ends a code now (and every visit made with it). Only its maker or an admin. */
export async function endGuestCode(id: string, user: { id: string; isAdmin: boolean }) {
	if (!/^[0-9a-f-]{36}$/.test(id)) return;
	await db()
		.delete(guestCodes)
		.where(user.isAdmin ? eq(guestCodes.id, id) : and(eq(guestCodes.id, id), eq(guestCodes.createdBy, user.id)));
}

/** The visit behind a cookie, while its code lasts. */
export async function authenticateGuest(raw: string | undefined | null): Promise<Guest | null> {
	if (!raw) return null;
	const code = normalize(raw);
	if (code.length !== LENGTH) return null;
	const [row] = await db()
		.select({ id: guestCodes.id, by: guestCodes.createdBy, byName: users.name, expiresAt: guestCodes.expiresAt })
		.from(guestCodes)
		.innerJoin(users, eq(users.id, guestCodes.createdBy))
		.where(and(eq(guestCodes.codeHash, sha256(code)), gt(guestCodes.expiresAt, new Date())));
	return row ? { codeId: row.id, by: row.by, byName: row.byName, expiresAt: row.expiresAt } : null;
}

// Wrong codes, per address: a handful of tries, then a pause (codes are random enough that guessing needs millions).
const MAX_TRIES = 10;
const WINDOW_MS = 15 * 60_000;
const tries = new Map<string, { n: number; since: number }>();

export type GuestLogin = { ok: true; guest: Guest; code: string } | { ok: false; error: string };

export async function guestLogin(raw: string, ip: string): Promise<GuestLogin> {
	const now = Date.now();
	for (const [k, v] of tries) if (now - v.since > WINDOW_MS) tries.delete(k);
	const t = tries.get(ip);
	if (t && t.n >= MAX_TRIES) return { ok: false, error: 'Muitas tentativas. Espere alguns minutos e tente de novo.' };
	const code = normalize(raw);
	const guest = code.length === LENGTH ? await authenticateGuest(code) : null;
	if (!guest) {
		tries.set(ip, { n: (t?.n ?? 0) + 1, since: t?.since ?? now });
		return { ok: false, error: code.length === LENGTH ? 'Código inválido ou expirado. Peça um novo a quem te convidou.' : 'O código tem 8 letras e números.' };
	}
	return { ok: true, guest, code };
}

export function setGuestCookie(cookies: Cookies, code: string, expiresAt: Date) {
	cookies.set(GUEST_COOKIE, code, {
		path: '/',
		httpOnly: true,
		sameSite: 'lax',
		secure: !env.ORIGIN?.startsWith('http://'),
		expires: expiresAt
	});
}

/**
 * What a visitor may open: the Diário, the Retrospectiva and a photo's page, and the reads behind them.
 * Everything else (map, itinerary, Cotinha, uploads, likes, comments, originals, people's locations) is off limits.
 */
const GUEST_PAGES = [/^\/$/, /^\/retro$/, /^\/m\/[0-9a-f-]{36}$/, /^\/visitante$/];
const GUEST_APIS = [/^\/api\/feed$/, /^\/api\/feed\/media$/, /^\/api\/retro$/];

export function guestAllowed(method: string, path: string, isApi: boolean) {
	if (path === '/visitante') return true; // its own form (sign in again / leave)
	if (method !== 'GET' && method !== 'HEAD') return false;
	return (isApi ? GUEST_APIS : GUEST_PAGES).some((r) => r.test(path));
}

// ── what a visitor sees: the photos and videos, without where they were taken (no map for visitors) ──

type Located = { type?: string; lat?: number | null; lng?: number | null };

/** No check-ins (they are places on the map) and no photo locations. */
export function forGuestItems<T extends Located>(items: T[]): T[] {
	return items.filter((i) => i.type !== 'checkin').map((i) => ({ ...i, lat: null, lng: null }));
}

/** The Diário's pages without check-in posts or photo locations. */
export function forGuestPage<P extends { type: string; items?: Located[] }, F extends { posts: P[] }>(page: F): F {
	return {
		...page,
		posts: page.posts.filter((p) => p.type !== 'checkin').map((p) => (p.items ? { ...p, items: forGuestItems(p.items) } : p))
	};
}
