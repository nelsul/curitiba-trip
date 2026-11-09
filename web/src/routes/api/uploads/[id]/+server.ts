import { deleteObject } from '$lib/server/images';
import { json as reply } from '@sveltejs/kit';
import { AbortMultipartUploadCommand } from '@aws-sdk/client-s3';
import { and, eq } from 'drizzle-orm';
import { db, media } from '$lib/server/db';
import { r2 } from '$lib/server/r2';
import { ownedUpload } from '$lib/server/owned-upload';
import type { RequestHandler } from './$types';

/** Cancel an unfinished upload. */
export const DELETE: RequestHandler = async ({ params, locals }) => {
	const m = await ownedUpload(params.id, locals.user!.id);
	if (m.status === 'uploading' && m.uploadId) {
		const { s3, bucket } = r2();
		await s3.send(new AbortMultipartUploadCommand({ Bucket: bucket, Key: m.originalKey, UploadId: m.uploadId })).catch(() => {});
		await db().delete(media).where(and(eq(media.id, m.id), eq(media.status, 'uploading')));
		await deleteObject(m.previewKey);
	}
	return reply({ ok: true });
};
