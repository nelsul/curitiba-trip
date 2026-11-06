import { error, json as reply } from '@sveltejs/kit';
import { CreateMultipartUploadCommand } from '@aws-sdk/client-s3';
import { randomUUID } from 'node:crypto';
import { db, media, type LocationSource, type TimeSource } from '$lib/server/db';
import { r2 } from '$lib/server/r2';
import { clip, isLat, isLng, json } from '$lib/server/validate';
import { kindOf, MAX_FILE_BYTES, PART_SIZE } from '$lib/upload-config';
import type { RequestHandler } from './$types';

type Body = {
	name: string;
	size: number;
	type: string;
	takenAt?: string | null;
	takenAtSource?: TimeSource;
	lat?: number | null;
	lng?: number | null;
	locationSource?: LocationSource | null;
	caption?: string;
};

export const POST: RequestHandler = async ({ request, locals }) => {
	const b = await json<Body>(request);
	const name = clip(b.name, 200) || 'arquivo';
	const size = Number(b.size);
	if (!Number.isFinite(size) || size <= 0) error(400, 'Arquivo vazio.');
	if (size > MAX_FILE_BYTES) error(400, 'Arquivo grande demais (máximo 20 GB).');
	const kind = kindOf(name, String(b.type ?? ''));
	if (!kind) error(400, 'Só fotos e vídeos.');

	const hasLoc = isLat(b.lat) && isLng(b.lng);
	const takenAt = b.takenAt ? new Date(b.takenAt) : null;
	const validTaken = takenAt && !Number.isNaN(takenAt.getTime()) ? takenAt : null;

	const id = randomUUID();
	const safe = name.normalize('NFKD').replace(/[^\w.\-]+/g, '_').slice(-120);
	const key = `originals/${locals.user!.id}/${id}/${safe}`;
	const mimeType = b.type || (kind === 'video' ? 'video/quicktime' : 'application/octet-stream');

	const { s3, bucket } = r2();
	const mp = await s3.send(new CreateMultipartUploadCommand({ Bucket: bucket, Key: key, ContentType: mimeType }));

	await db()
		.insert(media)
		.values({
			id,
			userId: locals.user!.id,
			kind,
			status: 'uploading',
			uploadId: mp.UploadId!,
			originalKey: key,
			originalName: name,
			mimeType,
			sizeBytes: size,
			takenAt: validTaken ?? new Date(),
			takenAtSource: validTaken ? (b.takenAtSource === 'exif' ? 'exif' : 'file') : 'upload',
			lat: hasLoc ? b.lat : null,
			lng: hasLoc ? b.lng : null,
			locationSource: hasLoc ? (b.locationSource ?? 'device') : null,
			caption: clip(b.caption, 2000)
		});

	return reply({ id, partSize: PART_SIZE, partCount: Math.ceil(size / PART_SIZE) });
};
