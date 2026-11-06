import { error, json as reply } from '@sveltejs/kit';
import { CompleteMultipartUploadCommand } from '@aws-sdk/client-s3';
import { eq } from 'drizzle-orm';
import { db, media } from '$lib/server/db';
import { r2 } from '$lib/server/r2';
import { enqueueMedia } from '$lib/server/queue';
import { ownedUpload } from '$lib/server/owned-upload';
import { json } from '$lib/server/validate';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ params, request, locals }) => {
	const m = await ownedUpload(params.id, locals.user!.id);
	if (m.status !== 'uploading' || !m.uploadId) error(409, 'Este envio já terminou.');
	const { parts } = await json<{ parts: { n: number; etag: string }[] }>(request);
	if (!Array.isArray(parts) || parts.length === 0) error(400, 'Partes ausentes');
	const sorted = [...parts].sort((a, b) => a.n - b.n);
	const { s3, bucket } = r2();
	await s3.send(
		new CompleteMultipartUploadCommand({
			Bucket: bucket,
			Key: m.originalKey,
			UploadId: m.uploadId,
			MultipartUpload: { Parts: sorted.map((p) => ({ PartNumber: p.n, ETag: p.etag })) }
		})
	);
	await db().update(media).set({ status: 'processing', uploadId: null }).where(eq(media.id, m.id));
	await enqueueMedia(m.id);
	return reply({ ok: true });
};
