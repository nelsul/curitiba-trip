import { error } from '@sveltejs/kit';
import { and, desc, eq, inArray } from 'drizzle-orm';
import { db, splitShares, splits, users } from './db';
import { clip } from './validate';
import type { Actor } from './details';
import { equalParts } from '$lib/money';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const MAX_CENTS = 100_000_000; // R$ 1 milhão

export type SplitShare = { userId: string; amountCents: number; paidAt: string | null };
export type Split = {
	id: string;
	title: string;
	totalCents: number;
	payerId: string;
	pixKey: string;
	note: string;
	createdAt: string;
	remindedAt: string | null;
	shares: SplitShare[];
};

/** Every cotinha, newest first, plus the Pix key I used last (to prefill a new one). */
export async function listSplits(me: string) {
	const rows = await db().select().from(splits).orderBy(desc(splits.createdAt));
	const shares = rows.length
		? await db().select().from(splitShares).where(inArray(splitShares.splitId, rows.map((r) => r.id)))
		: [];
	const list: Split[] = rows.map((r) => ({
		id: r.id,
		title: r.title,
		totalCents: r.totalCents,
		payerId: r.payerId,
		pixKey: r.pixKey,
		note: r.note,
		createdAt: r.createdAt.toISOString(),
		remindedAt: r.remindedAt?.toISOString() ?? null,
		shares: shares
			.filter((s) => s.splitId === r.id)
			.map((s) => ({ userId: s.userId, amountCents: s.amountCents, paidAt: s.paidAt?.toISOString() ?? null }))
	}));
	const myPix = rows.find((r) => r.payerId === me && r.pixKey)?.pixKey ?? '';
	return { splits: list, myPix };
}

type Body = {
	title?: unknown;
	totalCents?: unknown;
	pixKey?: unknown;
	note?: unknown;
	/** user ids splitting it (may include the payer) */
	participants?: unknown;
	/** optional custom parts; they must add up to totalCents */
	shares?: unknown;
};

/** New cotinha paid by `payer`. The payer's own part (if they're in it) starts as paid. */
export async function createSplit(payer: string, b: Body) {
	const title = clip(b.title, 120);
	const totalCents = Number(b.totalCents);
	if (!title) error(400, 'Diga o que foi comprado.');
	if (!Number.isInteger(totalCents) || totalCents <= 0 || totalCents > MAX_CENTS) error(400, 'Valor inválido.');

	let parts: { userId: string; amountCents: number }[];
	if (Array.isArray(b.shares) && b.shares.length) {
		parts = b.shares.map((s: { userId?: unknown; amountCents?: unknown }) => ({ userId: String(s.userId), amountCents: Number(s.amountCents) }));
		if (parts.some((p) => !Number.isInteger(p.amountCents) || p.amountCents < 0)) error(400, 'Valor inválido.');
		if (parts.reduce((a, p) => a + p.amountCents, 0) !== totalCents) error(400, 'As partes precisam somar o total.');
	} else {
		const ids = Array.isArray(b.participants) ? [...new Set(b.participants.map(String))] : [];
		if (!ids.length) error(400, 'Escolha quem divide.');
		const amounts = equalParts(totalCents, ids.length);
		parts = ids.map((userId, i) => ({ userId, amountCents: amounts[i] }));
	}
	if (parts.some((p) => !UUID.test(p.userId)) || new Set(parts.map((p) => p.userId)).size !== parts.length) error(400, 'Pessoas inválidas.');
	const known = await db().select({ id: users.id }).from(users).where(inArray(users.id, parts.map((p) => p.userId)));
	if (known.length !== parts.length) error(400, 'Pessoas inválidas.');

	return db().transaction(async (tx) => {
		const [s] = await tx
			.insert(splits)
			.values({ title, totalCents, payerId: payer, pixKey: clip(b.pixKey, 140), note: clip(b.note, 1000) })
			.returning({ id: splits.id });
		const now = new Date();
		await tx.insert(splitShares).values(
			parts.map((p) => ({ splitId: s.id, ...p, ...(p.userId === payer ? { paidAt: now, paidBy: payer } : {}) }))
		);
		return s.id;
	});
}

async function splitRow(id: string) {
	if (!UUID.test(id)) error(404, 'Cotinha não encontrada.');
	const [s] = await db().select().from(splits).where(eq(splits.id, id));
	if (!s) error(404, 'Cotinha não encontrada.');
	return s;
}

/** Only who paid (or an admin) deletes it. */
export async function deleteSplit(id: string, user: Actor) {
	const s = await splitRow(id);
	if (s.payerId !== user.id && !user.isAdmin) error(403, 'Só quem pagou pode apagar.');
	await db().delete(splits).where(eq(splits.id, s.id));
}

/** The person themselves or who paid marks a part as paid (or not). */
export async function setPaid(id: string, user: Actor, b: { userId?: unknown; paid?: unknown }) {
	const s = await splitRow(id);
	const target = typeof b.userId === 'string' ? b.userId : user.id;
	if (target !== user.id && s.payerId !== user.id && !user.isAdmin) error(403, 'Só a própria pessoa ou quem pagou marca isso.');
	const paid = b.paid !== false;
	const done = await db()
		.update(splitShares)
		.set(paid ? { paidAt: new Date(), paidBy: user.id } : { paidAt: null, paidBy: null })
		.where(and(eq(splitShares.splitId, s.id), eq(splitShares.userId, target)))
		.returning({ userId: splitShares.userId });
	if (!done.length) error(404, 'Essa pessoa não está nessa cotinha.');
}

/** Who paid nudges everyone who hasn't paid yet (the apps show a notification). At most once every 10 minutes. */
export async function remind(id: string, user: Actor) {
	const s = await splitRow(id);
	if (s.payerId !== user.id && !user.isAdmin) error(403, 'Só quem pagou pode cobrar.');
	if (s.remindedAt && Date.now() - s.remindedAt.getTime() < 10 * 60_000) error(429, 'Você acabou de cobrar. Espere uns minutinhos.');
	await db().update(splits).set({ remindedAt: new Date() }).where(eq(splits.id, s.id));
}
