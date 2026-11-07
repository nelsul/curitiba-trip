import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

export type R2Config = { accountId: string; accessKeyId: string; secretAccessKey: string; bucket: string };

export function r2ConfigFrom(env: Record<string, string | undefined>): R2Config {
	const cfg = {
		accountId: env.R2_ACCOUNT_ID ?? '',
		accessKeyId: env.R2_ACCESS_KEY_ID ?? '',
		secretAccessKey: env.R2_SECRET_ACCESS_KEY ?? '',
		bucket: env.R2_BUCKET ?? ''
	};
	for (const [k, v] of Object.entries(cfg)) if (!v) throw new Error(`R2 config missing: ${k}`);
	return cfg;
}

export function createR2(cfg: R2Config) {
	return new S3Client({
		region: 'auto',
		endpoint: `https://${cfg.accountId}.r2.cloudflarestorage.com`,
		credentials: { accessKeyId: cfg.accessKeyId, secretAccessKey: cfg.secretAccessKey },
		// R2 does not support the newer default checksums on presigned/multipart requests
		requestChecksumCalculation: 'WHEN_REQUIRED',
		responseChecksumValidation: 'WHEN_REQUIRED'
	});
}

const DAY = 86_400_000;

/**
 * Presigned GET that stays identical for a whole UTC day (signed at midnight, valid 2 days),
 * so browsers can cache images across page loads.
 */
export function stableGetUrl(
	s3: S3Client,
	bucket: string,
	key: string,
	opts: { downloadName?: string } = {}
) {
	const signingDate = new Date(Math.floor(Date.now() / DAY) * DAY);
	const cmd = new GetObjectCommand({
		Bucket: bucket,
		Key: key,
		...(opts.downloadName
			? { ResponseContentDisposition: `attachment; filename*=UTF-8''${encodeURIComponent(opts.downloadName)}` }
			: {})
	});
	return getSignedUrl(s3, cmd, { expiresIn: 2 * 86_400, signingDate });
}
