import { error, json as reply } from '@sveltejs/kit';
import { UploadPartCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { r2 } from '$lib/server/r2';
import { ownedUpload } from '$lib/server/owned-upload';
import { json } from '$lib/server/validate';
import { MAX_PARTS } from '$lib/upload-config';
import type { RequestHandler } from './$types';

/** Presigned URLs for a batch of parts (the client asks for them as it goes). */
export const POST: RequestHandler = async ({ params, request, locals }) => {
	const m = await ownedUpload(params.id, locals.user!.id);
	if (m.status !== 'uploading' || !m.uploadId) error(409, 'Este envio já terminou.');
	const { parts } = await json<{ parts: number[] }>(request);
	if (!Array.isArray(parts) || parts.length === 0 || parts.length > 50) error(400, 'Lista de partes inválida');
	const { s3, bucket } = r2();
	const urls: Record<number, string> = {};
	for (const n of parts) {
		if (!Number.isInteger(n) || n < 1 || n > MAX_PARTS) error(400, 'Parte inválida');
		urls[n] = await getSignedUrl(
			s3,
			new UploadPartCommand({ Bucket: bucket, Key: m.originalKey, UploadId: m.uploadId, PartNumber: n }),
			{ expiresIn: 6 * 3600 }
		);
	}
	return reply({ urls });
};
