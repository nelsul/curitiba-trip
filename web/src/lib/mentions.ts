// @mentions in comments: suggestions while typing and highlighting in the text. The server decides who was
// mentioned (src/lib/server/comments.ts) and notifies them.

type P = { id: string; name: string };

export const foldText = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();

/** The "@par" being typed right before the caret (null when not typing a mention). */
export function mentionQuery(text: string, caret: number) {
	const before = text.slice(0, caret);
	const m = /(^|[^\p{L}\p{N}_])@([\p{L}\p{N}_]*(?: [\p{L}\p{N}_]*)?)$/u.exec(before);
	if (!m || m[2].length > 30) return null;
	return { query: m[2], start: caret - m[2].length - 1 };
}

export function suggest<T extends P>(people: T[], query: string): T[] {
	const q = foldText(query.trim());
	return people
		.filter((p) => !q || foldText(p.name).startsWith(q) || foldText(p.name).split(/\s+/).some((w) => w.startsWith(q)))
		.slice(0, 6);
}

/** Splits a comment into plain text and @mention parts (matching people's full or first names). */
export function mentionParts(text: string, people: P[]): { text: string; mention: boolean }[] {
	const names = [...new Set(people.flatMap((p) => [p.name, p.name.split(/\s+/)[0]]))].sort((a, b) => b.length - a.length);
	if (!names.length) return [{ text, mention: false }];
	const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
	const re = new RegExp(`@(?:${names.map(esc).join('|')})(?![\\p{L}\\p{N}_])`, 'giu');
	const out: { text: string; mention: boolean }[] = [];
	let last = 0;
	for (const m of text.matchAll(re)) {
		if (m.index! > last) out.push({ text: text.slice(last, m.index), mention: false });
		out.push({ text: m[0], mention: true });
		last = m.index! + m[0].length;
	}
	if (last < text.length) out.push({ text: text.slice(last), mention: false });
	return out;
}
