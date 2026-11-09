import { kindOf } from './upload-config';

export type FileMeta = {
	kind: 'photo' | 'video' | null;
	takenAt: string | null;
	takenAtSource: 'exif' | 'file';
	lat: number | null;
	lng: number | null;
	locationSource: 'exif' | 'device' | 'manual' | null;
};

/** "2026:11:12 14:30:00" + "-03:00" → ISO. Assumes Curitiba time when the photo has no offset. */
function exifDateToIso(raw: unknown, offset: unknown): string | null {
	if (typeof raw !== 'string') return null;
	const m = raw.match(/^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})/);
	if (!m) return null;
	const off = typeof offset === 'string' && /^[+-]\d{2}:\d{2}$/.test(offset) ? offset : '-03:00';
	const d = new Date(`${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}${off}`);
	return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

/** Reads GPS and capture time from photos in the browser. Videos are read later by the worker. */
export async function readMeta(file: File): Promise<FileMeta> {
	const kind = kindOf(file.name, file.type);
	const meta: FileMeta = {
		kind,
		takenAt: file.lastModified ? new Date(file.lastModified).toISOString() : null,
		takenAtSource: 'file',
		lat: null,
		lng: null,
		locationSource: null
	};
	if (kind !== 'photo') return meta;
	try {
		// the "lite" build (JPEG/HEIC/TIFF, ~45 KB) instead of the full one (~75 KB)
		const exifr = (await import('exifr/dist/lite.esm.mjs')).default;
		const [gps, tags] = await Promise.all([
			exifr.gps(file).catch(() => null),
			exifr
				.parse(file, { pick: ['DateTimeOriginal', 'OffsetTimeOriginal', 'CreateDate', 'OffsetTime'], reviveValues: false })
				.catch(() => null)
		]);
		if (gps && Number.isFinite(gps.latitude) && Number.isFinite(gps.longitude) && !(gps.latitude === 0 && gps.longitude === 0)) {
			meta.lat = gps.latitude;
			meta.lng = gps.longitude;
			meta.locationSource = 'exif';
		}
		const iso = exifDateToIso(tags?.DateTimeOriginal ?? tags?.CreateDate, tags?.OffsetTimeOriginal ?? tags?.OffsetTime);
		if (iso) {
			meta.takenAt = iso;
			meta.takenAtSource = 'exif';
		}
	} catch {
		/* unreadable metadata is fine */
	}
	return meta;
}

export type UploadOptions = {
	file: File;
	meta: FileMeta;
	caption: string;
	onProgress: (sentBytes: number) => void;
	onStatus?: (text: string) => void;
	signal: AbortSignal;
};

const CONCURRENCY = 3;
const MAX_ATTEMPTS = 8;

async function api<T>(url: string, init: RequestInit): Promise<T> {
	const r = await fetch(url, { ...init, headers: { 'content-type': 'application/json', ...(init.headers ?? {}) } });
	if (!r.ok) {
		let msg = `Erro ${r.status}`;
		try { msg = (await r.json()).message ?? msg; } catch {}
		throw Object.assign(new Error(msg), { status: r.status });
	}
	return r.json();
}

const sleep = (ms: number, signal: AbortSignal) =>
	new Promise<void>((res, rej) => {
		const t = setTimeout(res, ms);
		signal.addEventListener('abort', () => { clearTimeout(t); rej(new DOMException('Cancelado', 'AbortError')); }, { once: true });
	});

const waitOnline = (signal: AbortSignal) =>
	navigator.onLine
		? Promise.resolve()
		: new Promise<void>((res, rej) => {
				window.addEventListener('online', () => res(), { once: true });
				signal.addEventListener('abort', () => rej(new DOMException('Cancelado', 'AbortError')), { once: true });
			});

function putPart(url: string, blob: Blob, onLoaded: (n: number) => void, signal: AbortSignal): Promise<string> {
	return new Promise((resolve, reject) => {
		const xhr = new XMLHttpRequest();
		xhr.open('PUT', url);
		xhr.upload.onprogress = (e) => onLoaded(e.loaded);
		xhr.onload = () => {
			const etag = xhr.getResponseHeader('ETag');
			if (xhr.status >= 200 && xhr.status < 300 && etag) resolve(etag);
			else reject(new Error(`R2 respondeu ${xhr.status}`));
		};
		xhr.onerror = () => reject(new Error('Falha de rede'));
		xhr.ontimeout = () => reject(new Error('Tempo esgotado'));
		signal.addEventListener('abort', () => xhr.abort(), { once: true });
		xhr.onabort = () => reject(new DOMException('Cancelado', 'AbortError'));
		xhr.send(blob);
	});
}

/** Multipart upload straight to R2. Returns the media id. */
export async function uploadFile({ file, meta, caption, onProgress, onStatus, signal }: UploadOptions): Promise<string> {
	const created = await api<{ id: string; partSize: number; partCount: number }>('/api/uploads', {
		method: 'POST',
		body: JSON.stringify({ name: file.name, size: file.size, type: file.type, caption, ...meta }),
		signal
	});
	const { id, partSize, partCount } = created;
	const cancel = () => fetch(`/api/uploads/${id}`, { method: 'DELETE' }).catch(() => {});

	try {
		const urls = new Map<number, string>();
		const loaded = new Map<number, number>();
		const etags: { n: number; etag: string }[] = [];
		let done = 0;
		const report = () => onProgress(done + [...loaded.values()].reduce((a, b) => a + b, 0));

		const getUrl = async (n: number) => {
			if (!urls.has(n)) {
				const batch = Array.from({ length: Math.min(20, partCount - n + 1) }, (_, i) => n + i).filter((k) => !urls.has(k));
				const r = await api<{ urls: Record<string, string> }>(`/api/uploads/${id}/parts`, {
					method: 'POST',
					body: JSON.stringify({ parts: batch }),
					signal
				});
				for (const [k, v] of Object.entries(r.urls)) urls.set(Number(k), v);
			}
			return urls.get(n)!;
		};

		let next = 1;
		const worker = async () => {
			while (next <= partCount) {
				const n = next++;
				const start = (n - 1) * partSize;
				const blob = file.slice(start, Math.min(start + partSize, file.size));
				for (let attempt = 1; ; attempt++) {
					try {
						await waitOnline(signal);
						const etag = await putPart(await getUrl(n), blob, (b) => { loaded.set(n, b); report(); }, signal);
						loaded.delete(n);
						done += blob.size;
						etags.push({ n, etag });
						report();
						break;
					} catch (e) {
						loaded.delete(n);
						report();
						if (signal.aborted || (e as Error).name === 'AbortError') throw e;
						if (attempt >= MAX_ATTEMPTS) throw e;
						urls.delete(n); // URL may have expired
						onStatus?.(`Conexão instável, tentando de novo (${attempt}/${MAX_ATTEMPTS - 1})…`);
						await sleep(Math.min(30_000, 1000 * 2 ** attempt), signal);
						onStatus?.('');
					}
				}
			}
		};
		await Promise.all(Array.from({ length: Math.min(CONCURRENCY, partCount) }, worker));
		await api(`/api/uploads/${id}/complete`, { method: 'POST', body: JSON.stringify({ parts: etags }), signal });
		return id;
	} catch (e) {
		await cancel();
		throw e;
	}
}
