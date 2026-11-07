export const TZ = 'America/Sao_Paulo';

const fmt = (o: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat('pt-BR', { timeZone: TZ, ...o });
const time = fmt({ hour: '2-digit', minute: '2-digit' });
const dayMonth = fmt({ day: '2-digit', month: '2-digit' });
const weekday = fmt({ weekday: 'short' });
const longDay = fmt({ weekday: 'long', day: 'numeric', month: 'long' });
const isoDay = new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit' });

const d = (v: Date | string | number) => (v instanceof Date ? v : new Date(v));

/** "2026-11-12" in Curitiba time */
export const dayKey = (v: Date | string | number) => isoDay.format(d(v));
export const fmtTime = (v: Date | string | number) => time.format(d(v));
export const fmtDayMonth = (v: Date | string | number) => dayMonth.format(d(v));
export const fmtDateTime = (v: Date | string | number) => `${dayMonth.format(d(v))} ${time.format(d(v))}`;
export const fmtWeekday = (v: Date | string | number) => weekday.format(d(v)).replace('.', '');
/** dayKey "2026-11-12" → "quinta-feira, 12 de novembro" */
export const fmtLongDay = (key: string) => longDay.format(new Date(`${key}T12:00:00-03:00`));
export const dayKeyLabel = (key: string) => {
	const date = new Date(`${key}T12:00:00-03:00`);
	return { day: key.slice(8), weekday: fmtWeekday(date) };
};

export function fmtAgo(v: Date | string | number) {
	const s = Math.round((Date.now() - d(v).getTime()) / 1000);
	if (s < 60) return 'agora';
	if (s < 3600) return `há ${Math.floor(s / 60)} min`;
	if (s < 86400) return `há ${Math.floor(s / 3600)} h`;
	return fmtDateTime(v);
}

export function fmtBytes(n: number) {
	if (n < 1024 ** 2) return `${Math.max(1, Math.round(n / 1024))} KB`;
	if (n < 1024 ** 3) return `${(n / 1024 ** 2).toFixed(1).replace('.', ',')} MB`;
	return `${(n / 1024 ** 3).toFixed(2).replace('.', ',')} GB`;
}

export function fmtDuration(sec: number) {
	const m = Math.floor(sec / 60);
	const s = Math.round(sec % 60);
	return `${m}:${String(s).padStart(2, '0')}`;
}

export const initials = (name: string) =>
	name
		.split(/\s+/)
		.map((p) => p[0])
		.join('')
		.slice(0, 2)
		.toUpperCase();
