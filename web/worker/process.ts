import { execFile } from 'node:child_process';
import { createWriteStream } from 'node:fs';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pipeline } from 'node:stream/promises';
import type { Readable } from 'node:stream';
import { promisify } from 'node:util';
import { DeleteObjectCommand, GetObjectCommand, PutObjectCommand, type S3Client } from '@aws-sdk/client-s3';
import { eq } from 'drizzle-orm';
import type { Db } from '../src/lib/server/shared/db';
import { media, type Media } from '../src/lib/server/db/schema';

const run = promisify(execFile);
const sh = (cmd: string, args: string[]) => run(cmd, args, { maxBuffer: 64 * 1024 * 1024 });

type Ctx = { db: Db; s3: S3Client; bucket: string; log: (...a: unknown[]) => void };

// ---------- metadata ----------

type Exif = Record<string, unknown>;

async function readExif(file: string): Promise<Exif> {
	const { stdout } = await sh('exiftool', ['-json', '-n', '-api', 'largefilesupport=1', file]);
	return (JSON.parse(stdout)[0] ?? {}) as Exif;
}

const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : typeof v === 'string' && v.trim() !== '' && Number.isFinite(Number(v)) ? Number(v) : null);

export function gpsFrom(x: Exif): { lat: number; lng: number } | null {
	let lat = num(x.GPSLatitude);
	let lng = num(x.GPSLongitude);
	if ((lat === null || lng === null) && typeof x.GPSCoordinates === 'string') {
		const [a, b] = x.GPSCoordinates.trim().split(/[\s,]+/).map(Number);
		if (Number.isFinite(a) && Number.isFinite(b)) [lat, lng] = [a, b];
	}
	if (lat === null || lng === null || Math.abs(lat) > 90 || Math.abs(lng) > 180 || (lat === 0 && lng === 0)) return null;
	return { lat, lng };
}

const DATE_RE = /^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?/;

function parseDate(v: unknown, fallbackOffset: string | null): Date | null {
	if (typeof v !== 'string') return null;
	const m = v.match(DATE_RE);
	if (!m || m[1] === '0000') return null;
	let off = m[7] ?? fallbackOffset;
	if (!off) return null;
	if (off !== 'Z' && !off.includes(':')) off = `${off.slice(0, 3)}:${off.slice(3)}`;
	const d = new Date(`${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}${off}`);
	return Number.isNaN(d.getTime()) ? null : d;
}

/** Capture time. Photos store local time (+ optional offset); QuickTime CreateDate is UTC. */
export function takenFrom(x: Exif, kind: 'photo' | 'video'): Date | null {
	const offset = (typeof x.OffsetTimeOriginal === 'string' && x.OffsetTimeOriginal) || null;
	if (kind === 'photo') {
		return parseDate(x.DateTimeOriginal, offset ?? '-03:00') ?? parseDate(x.CreateDate, offset ?? '-03:00');
	}
	// iPhone videos: Keys:CreationDate carries its own offset
	return parseDate(x.CreationDate, null) ?? parseDate(x.CreateDate, 'Z') ?? parseDate(x.MediaCreateDate, 'Z');
}

// ---------- media tools ----------

async function vipsThumb(input: string, output: string, size: string, crop = false) {
	const args = [input, '--size', size, '-o', `${output}[Q=80,strip]`];
	if (crop) args.push('--smartcrop', 'attention');
	await sh('vipsthumbnail', args);
}

/**
 * The photo as a file libvips can read. If it can't open the original (an image format or HEIC variant it doesn't
 * know), ffmpeg decodes it to a lossless PNG first; EXIF stays on the original for GPS and time.
 */
async function decodable(src: string, dir: string, ctx: Ctx) {
	try {
		await sh('vipsheader', [src]);
		return src;
	} catch (e) {
		ctx.log(`libvips can't read ${src} (${e instanceof Error ? e.message.slice(0, 120) : e}); trying ffmpeg`);
		const png = join(dir, 'decoded.png');
		await sh('ffmpeg', ['-v', 'error', '-y', '-i', src, '-frames:v', '1', '-update', '1', png]);
		return png;
	}
}

async function vipsSize(file: string) {
	const [{ stdout: w }, { stdout: h }] = await Promise.all([
		sh('vipsheader', ['-f', 'width', file]),
		sh('vipsheader', ['-f', 'height', file])
	]);
	return { width: Number(w.trim()), height: Number(h.trim()) };
}

type Probe = {
	streams: { codec_type: string; width?: number; height?: number; color_transfer?: string; side_data_list?: { rotation?: number }[] }[];
	format: { duration?: string };
};

async function probe(file: string): Promise<Probe> {
	const { stdout } = await sh('ffprobe', ['-v', 'error', '-print_format', 'json', '-show_streams', '-show_format', file]);
	return JSON.parse(stdout);
}

async function transcode(input: string, output: string, hdr: boolean) {
	const scale = "scale='if(gt(iw,ih),min(1920,iw),-2)':'if(gt(iw,ih),-2,min(1920,ih))'";
	const tonemap = 'zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv';
	const vf = [hdr ? tonemap : null, scale, 'format=yuv420p'].filter(Boolean).join(',');
	await sh('nice', [
		'-n', '10', 'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', input,
		'-map', '0:v:0', '-map', '0:a:0?', '-vf', vf,
		// at most 30 fps and ~5 Mbps: a 4K/60 fps phone video becomes a light 1080p file for the feed and the reels
		'-fpsmax', '30',
		'-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23', '-maxrate', '5M', '-bufsize', '10M', '-profile:v', 'high',
		'-c:a', 'aac', '-b:a', '128k', '-ac', '2',
		'-movflags', '+faststart', '-threads', '2', output
	]);
}

// ---------- storage ----------

async function download(ctx: Ctx, key: string, dest: string) {
	const r = await ctx.s3.send(new GetObjectCommand({ Bucket: ctx.bucket, Key: key }));
	await pipeline(r.Body as Readable, createWriteStream(dest));
}

async function upload(ctx: Ctx, key: string, file: string, contentType: string) {
	await ctx.s3.send(
		new PutObjectCommand({
			Bucket: ctx.bucket,
			Key: key,
			Body: await readFile(file),
			ContentType: contentType,
			CacheControl: 'public, max-age=31536000, immutable'
		})
	);
}

// ---------- job ----------

export async function processMedia(ctx: Ctx, mediaId: string) {
	const [m] = await ctx.db.select().from(media).where(eq(media.id, mediaId));
	if (!m) return ctx.log(`media ${mediaId} not found, skipping`);
	if (m.status === 'uploading') throw new Error('upload not finished');

	const dir = await mkdtemp(join(tmpdir(), 'media-'));
	const t0 = Date.now();
	try {
		const ext = m.originalName.match(/\.[\w]+$/)?.[0]?.toLowerCase() ?? '';
		const src = join(dir, `original${ext}`);
		await download(ctx, m.originalKey, src);
		const exif = await readExif(src).catch(() => ({}) as Exif);
		const base = `derived/${m.id}`;
		const patch: Partial<Media> = {};

		if (m.kind === 'photo') {
			const display = join(dir, 'display.webp');
			const medium = join(dir, 'medium.webp');
			const thumb = join(dir, 'thumb.webp');
			const image = await decodable(src, dir, ctx);
			await vipsThumb(image, display, '2048x2048>');
			await vipsThumb(image, medium, '1080x1350>');
			await vipsThumb(image, thumb, '480x480', true);
			Object.assign(patch, await vipsSize(display));
			await upload(ctx, `${base}/display.webp`, display, 'image/webp');
			await upload(ctx, `${base}/medium.webp`, medium, 'image/webp');
			await upload(ctx, `${base}/thumb.webp`, thumb, 'image/webp');
			patch.displayKey = `${base}/display.webp`;
			patch.mediumKey = `${base}/medium.webp`;
			patch.thumbKey = `${base}/thumb.webp`;
		} else {
			const info = await probe(src);
			const v = info.streams.find((s) => s.codec_type === 'video');
			if (!v) throw new Error('no video stream');
			const hdr = ['arib-std-b67', 'smpte2084'].includes(v.color_transfer ?? '');
			const out = join(dir, 'video.mp4');
			await transcode(src, out, hdr);
			const outInfo = await probe(out);
			const ov = outInfo.streams.find((s) => s.codec_type === 'video')!;
			const duration = Number(outInfo.format.duration ?? info.format.duration ?? 0);
			const posterJpg = join(dir, 'poster.jpg');
			await sh('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-ss', String(Math.min(1, duration / 2)), '-i', out, '-frames:v', '1', '-q:v', '3', posterJpg]);
			const poster = join(dir, 'poster.webp');
			const thumb = join(dir, 'thumb.webp');
			await vipsThumb(posterJpg, poster, '1280x1280>');
			await vipsThumb(posterJpg, thumb, '480x480', true);
			await upload(ctx, `${base}/video.mp4`, out, 'video/mp4');
			await upload(ctx, `${base}/poster.webp`, poster, 'image/webp');
			await upload(ctx, `${base}/thumb.webp`, thumb, 'image/webp');
			Object.assign(patch, {
				videoKey: `${base}/video.mp4`,
				posterKey: `${base}/poster.webp`,
				thumbKey: `${base}/thumb.webp`,
				width: ov.width ?? null,
				height: ov.height ?? null,
				durationS: Number.isFinite(duration) ? duration : null
			});
		}

		// Metadata from the file wins over browser guesses, but never over a pin the owner placed.
		const gps = gpsFrom(exif);
		if (gps && m.locationSource !== 'manual') Object.assign(patch, { lat: gps.lat, lng: gps.lng, locationSource: 'exif' });
		const taken = takenFrom(exif, m.kind);
		if (taken && taken.getFullYear() > 2000) Object.assign(patch, { takenAt: taken, takenAtSource: 'exif' });

		await ctx.db
			.update(media)
			.set({ ...patch, status: 'ready', error: null, processedAt: new Date(), previewKey: null })
			.where(eq(media.id, m.id));
		// the low-res picture sent while waiting for Wi-Fi isn't needed anymore
		if (m.previewKey) await ctx.s3.send(new DeleteObjectCommand({ Bucket: ctx.bucket, Key: m.previewKey })).catch(() => {});
		const size = (await stat(src)).size;
		ctx.log(`ready ${m.kind} ${m.id} (${(size / 1e6).toFixed(1)} MB) in ${((Date.now() - t0) / 1000).toFixed(1)}s; gps=${gps ? 'yes' : 'no'} taken=${taken ? 'exif' : 'kept'}`);
	} catch (e) {
		const msg = e instanceof Error ? e.message.slice(0, 500) : String(e);
		await ctx.db.update(media).set({ status: 'failed', error: msg }).where(eq(media.id, m.id));
		throw e;
	} finally {
		await rm(dir, { recursive: true, force: true });
	}
}
