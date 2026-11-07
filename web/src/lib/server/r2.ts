import { env } from '$env/dynamic/private';
import type { S3Client } from '@aws-sdk/client-s3';
import { createR2, r2ConfigFrom, stableGetUrl } from './shared/r2';

let _s3: S3Client | undefined;
export function r2() {
	const cfg = r2ConfigFrom(env);
	_s3 ??= createR2(cfg);
	return { s3: _s3, bucket: cfg.bucket };
}

export function mediaUrl(key: string | null | undefined, downloadName?: string) {
	if (!key) return Promise.resolve(null);
	const { s3, bucket } = r2();
	return stableGetUrl(s3, bucket, key, { downloadName });
}
