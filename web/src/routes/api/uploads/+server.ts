import { error, json as reply } from '@sveltejs/kit';
import { AbortMultipartUploadCommand, CreateMultipartUploadCommand } from '@aws-sdk/client-s3';
import { and, eq } from 'drizzle-orm';
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
	/** iOS app: the photo-library ID. Re-sending the same photo returns the existing post instead of a copy. */
	clientAssetId?: string;
};

const LOCATION_SOURCES: LocationSource[] = ['exif', 'device', 'device-library', 'manual'];

export const POST: RequestHandler = async ({ request, locals }) => {
	const b = await json<Body>(request);
	const name = clip(b.name, 200) || 'arquivo';
	const size = Number(b.size);
	if (!Number.isFinite(size) || size <= 0) error(400, 'Arquivo vazio.');
	if (size > MAX_FILE_BYTES) error(400, 'Arquivo grande demais (máximo 20 GB).');
	const kind = kindOf(name, String(b.type ?? ''));
	if (!kind) error(400, 'Só fotos e vídeos.');

	const userId = locals.user!.id;
	const clientAssetId = clip(b.clientAssetId, 200) || null;
	if (clientAssetId) {
		const [prev] = await db()
			.select({ id: media.id, status: media.status, uploadId: media.uploadId, originalKey: media.originalKey, previewKey: media.previewKey })
			.from(media)
			.where(and(eq(media.userId, userId), eq(media.clientAssetId, clientAssetId)));
		if (prev && prev.status !== 'uploading') return reply({ id: prev.id, duplicate: true, status: prev.status });
		if (prev?.previewKey) {
			// already in the diary with its preview (likes and comments included): start the original over in place
			const { s3, bucket } = r2();
			if (prev.uploadId) await s3.send(new AbortMultipartUploadCommand({ Bucket: bucket, Key: prev.originalKey, UploadId: prev.uploadId })).catch(() => {});
			const mp = await s3.send(new CreateMultipartUploadCommand({ Bucket: bucket, Key: prev.originalKey, ContentType: b.type || undefined }));
			await db().update(media).set({ uploadId: mp.UploadId!, sizeBytes: size }).where(eq(media.id, prev.id));
			return reply({ id: prev.id, partSize: PART_SIZE, partCount: Math.ceil(size / PART_SIZE), preview: true });
		}
		if (prev) {
			// an earlier attempt never finished: drop it and start over
			const { s3, bucket } = r2();
			if (prev.uploadId) await s3.send(new AbortMultipartUploadCommand({ Bucket: bucket, Key: prev.originalKey, UploadId: prev.uploadId })).catch(() => {});
			await db().delete(media).where(eq(media.id, prev.id));
		}
	}

	const hasLoc = isLat(b.lat) && isLng(b.lng);
	const takenAt = b.takenAt ? new Date(b.takenAt) : null;
	const validTaken = takenAt && !Number.isNaN(takenAt.getTime()) ? takenAt : null;

	const id = randomUUID();
	const safe = name.normalize('NFKD').replace(/[^\w.\-]+/g, '_').slice(-120);
	const key = `originals/${userId}/${id}/${safe}`;
	const mimeType = b.type || (kind === 'video' ? 'video/quicktime' : 'application/octet-stream');

	const { s3, bucket } = r2();
	const mp = await s3.send(new CreateMultipartUploadCommand({ Bucket: bucket, Key: key, ContentType: mimeType }));

	try {
		await db()
		.insert(media)
		.values({
			id,
			userId,
			clientAssetId,
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
			locationSource: hasLoc ? (b.locationSource && LOCATION_SOURCES.includes(b.locationSource) ? b.locationSource : 'device') : null,
			caption: clip(b.caption, 2000)
		});
	} catch (e) {
		// two requests for the same photo at once: the unique index lets only one through
		await s3.send(new AbortMultipartUploadCommand({ Bucket: bucket, Key: key, UploadId: mp.UploadId! })).catch(() => {});
		if ((e as { code?: string }).code === '23505' || String((e as Error).cause ?? e).includes('media_user_asset_uq')) {
			const [dup] = await db().select({ id: media.id, status: media.status }).from(media).where(and(eq(media.userId, userId), eq(media.clientAssetId, clientAssetId!)));
			return reply({ id: dup?.id, duplicate: true, status: dup?.status });
		}
		throw e;
	}

	return reply({ id, partSize: PART_SIZE, partCount: Math.ceil(size / PART_SIZE) });
};
