import { env } from '$env/dynamic/private';
import { createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import type { Cookies } from '@sveltejs/kit';
import { and, desc, eq, gt, isNull } from 'drizzle-orm';
import { db, loginCodes, sessions, users, type SessionKind, type User } from './db';
import { sendLoginCode } from './mail';

export const SESSION_COOKIE = 'sessao';
const SESSION_DAYS = 60;
const CODE_TTL_MIN = 10;
const CODE_MAX_ATTEMPTS = 5;
const CODE_RESEND_SECONDS = 60;

export const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');
const hmacCode = (email: string, code: string) =>
	createHmac('sha256', env.AUTH_SECRET || 'dev-secret').update(`${email}:${code}`).digest('hex');

export const normalizeEmail = (e: string) => e.trim().toLowerCase();

export type SendResult = { ok: true; maskedEmail: string } | { ok: false; error: string };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

async function userById(id: string) {
	if (!UUID.test(id)) return null;
	const [u] = await db().select().from(users).where(eq(users.id, id));
	return u ?? null;
}

/** "maria.silva@example.com" → "ma•••@example.com" (shown on the public login page) */
export function maskEmail(email: string) {
	const [local, domain] = email.split('@');
	return `${local.slice(0, 2)}•••@${domain}`;
}

/** Sends a login code to the email of the person picked on the login page. */
export async function requestCode(userId: string): Promise<SendResult> {
	const user = await userById(userId);
	if (!user) return { ok: false, error: 'Pessoa não encontrada. Recarregue a página.' };
	const email = user.email;

	const [recent] = await db()
		.select({ createdAt: loginCodes.createdAt })
		.from(loginCodes)
		.where(and(eq(loginCodes.email, email), gt(loginCodes.createdAt, new Date(Date.now() - CODE_RESEND_SECONDS * 1000))))
		.limit(1);
	if (recent) return { ok: true, maskedEmail: maskEmail(email) }; // a code was just sent; don't spam

	const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
	await db().insert(loginCodes).values({
		email,
		codeHash: hmacCode(email, code),
		expiresAt: new Date(Date.now() + CODE_TTL_MIN * 60_000)
	});
	try {
		await sendLoginCode(email, user.name, code);
	} catch (e) {
		console.error('[auth] failed to send code', e);
		return { ok: false, error: 'Não foi possível enviar o e-mail agora. Tente de novo em instantes.' };
	}
	return { ok: true, maskedEmail: maskEmail(email) };
}

export type VerifyResult = { ok: true; token: string } | { ok: false; error: string };

/** Where the new session will live: a browser cookie, or a Bearer token held by the iOS app. */
export type SessionOptions = { kind?: SessionKind; deviceName?: string | null };

export async function verifyCode(userId: string, rawCode: string, opts: SessionOptions = {}): Promise<VerifyResult> {
	const picked = await userById(userId);
	if (!picked) return { ok: false, error: 'Pessoa não encontrada. Recarregue a página.' };
	const email = picked.email;
	const code = rawCode.replace(/\D/g, '');
	if (code.length !== 6) return { ok: false, error: 'O código tem 6 números.' };

	const [row] = await db()
		.select()
		.from(loginCodes)
		.where(and(eq(loginCodes.email, email), isNull(loginCodes.usedAt), gt(loginCodes.expiresAt, new Date())))
		.orderBy(desc(loginCodes.createdAt))
		.limit(1);
	if (!row) return { ok: false, error: 'Código expirado. Peça um novo.' };
	if (row.attempts >= CODE_MAX_ATTEMPTS) return { ok: false, error: 'Muitas tentativas. Peça um novo código.' };

	const a = Buffer.from(row.codeHash, 'hex');
	const b = Buffer.from(hmacCode(email, code), 'hex');
	if (a.length !== b.length || !timingSafeEqual(a, b)) {
		await db().update(loginCodes).set({ attempts: row.attempts + 1 }).where(eq(loginCodes.id, row.id));
		return { ok: false, error: 'Código incorreto.' };
	}

	await db().update(loginCodes).set({ usedAt: new Date() }).where(eq(loginCodes.id, row.id));
	return { ok: true, token: await createSession(picked.id, opts) };
}

export async function createSession(userId: string, { kind = 'cookie', deviceName = null }: SessionOptions = {}) {
	const token = randomBytes(32).toString('base64url');
	await db()
		.insert(sessions)
		.values({
			id: sha256(token),
			userId,
			kind,
			deviceName: deviceName?.trim().slice(0, 60) || null,
			lastUsedAt: new Date(),
			expiresAt: new Date(Date.now() + SESSION_DAYS * 86_400_000)
		});
	return token;
}

export type AuthResult = { user: User; sessionId: string; kind: SessionKind };

/** Resolves a cookie or Bearer token to its user. Sliding expiry; lastUsedAt is written at most hourly. */
export async function authenticate(token: string | undefined | null): Promise<AuthResult | null> {
	if (!token) return null;
	const id = sha256(token);
	const [row] = await db()
		.select({ user: users, expiresAt: sessions.expiresAt, kind: sessions.kind, lastUsedAt: sessions.lastUsedAt })
		.from(sessions)
		.innerJoin(users, eq(users.id, sessions.userId))
		.where(eq(sessions.id, id));
	if (!row) return null;
	const now = Date.now();
	if (row.expiresAt.getTime() < now) {
		await db().delete(sessions).where(eq(sessions.id, id));
		return null;
	}
	const patch: { expiresAt?: Date; lastUsedAt?: Date } = {};
	// sliding expiration: refresh when less than half the lifetime is left
	if (row.expiresAt.getTime() - now < (SESSION_DAYS / 2) * 86_400_000) patch.expiresAt = new Date(now + SESSION_DAYS * 86_400_000);
	if (!row.lastUsedAt || now - row.lastUsedAt.getTime() > 3600_000) patch.lastUsedAt = new Date(now);
	if (patch.expiresAt || patch.lastUsedAt) await db().update(sessions).set(patch).where(eq(sessions.id, id));
	return { user: row.user, sessionId: id, kind: row.kind };
}

/** `Authorization: Bearer <token>` → token (the iOS app); otherwise null. */
export function bearerToken(header: string | null) {
	const m = header?.match(/^Bearer\s+([A-Za-z0-9_-]{20,200})$/);
	return m ? m[1] : null;
}

export async function revokeSession(sessionId: string) {
	await db().delete(sessions).where(eq(sessions.id, sessionId));
}

export function setSessionCookie(cookies: Cookies, token: string) {
	cookies.set(SESSION_COOKIE, token, {
		path: '/',
		httpOnly: true,
		sameSite: 'lax',
		secure: !env.ORIGIN?.startsWith('http://'),
		maxAge: SESSION_DAYS * 86_400
	});
}

export async function signOut(cookies: Cookies) {
	const token = cookies.get(SESSION_COOKIE);
	if (token) await db().delete(sessions).where(eq(sessions.id, sha256(token)));
	cookies.delete(SESSION_COOKIE, { path: '/' });
}
