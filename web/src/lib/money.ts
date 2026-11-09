/** 12345 → "R$ 123,45" */
export const brl = (cents: number) =>
	(cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', minimumFractionDigits: 2 });

/** "123,45" / "123.45" / "1.234,5" → 12345 cents (null when it isn't a number) */
export function parseCents(text: string): number | null {
	let t = text.replace(/[^\d,.]/g, '');
	if (!t) return null;
	if (t.includes(',')) t = t.replace(/\./g, '').replace(',', '.');
	else if ((t.match(/\./g) ?? []).length > 1 || /\.\d{3}$/.test(t)) t = t.replace(/\./g, '');
	const n = Math.round(Number(t) * 100);
	return Number.isFinite(n) ? n : null;
}

/** Equal parts; the leftover cents go to the first people, so the parts always add up. */
export function equalParts(totalCents: number, n: number) {
	const base = Math.floor(totalCents / n);
	return Array.from({ length: n }, (_, i) => base + (i < totalCents - base * n ? 1 : 0));
}
