import { DeleteObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { randomBytes } from 'node:crypto';
import { r2 } from './r2';

/** Detect the image type from its first bytes instead of trusting headers. */
export function sniffImage(b: Uint8Array): { type: string; ext: string } | null {
	if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return { type: 'image/jpeg', ext: 'jpg' };
	if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return { type: 'image/png', ext: 'png' };
	if (String.fromCharCode(...b.slice(0, 4)) === 'RIFF' && String.fromCharCode(...b.slice(8, 12)) === 'WEBP') return { type: 'image/webp', ext: 'webp' };
	return null;
}

/** Stores an already-validated image under `<prefix>/<random>.<ext>` (new URL every time, so caches never go stale). */
export async function putImage(prefix: string, body: Uint8Array, kind: { type: string; ext: string }) {
	const key = `${prefix}/${randomBytes(8).toString('hex')}.${kind.ext}`;
	const { s3, bucket } = r2();
	await s3.send(new PutObjectCommand({ Bucket: bucket, Key: key, Body: body, ContentType: kind.type, CacheControl: 'public, max-age=31536000, immutable' }));
	return key;
}

export async function deleteObject(key: string | null | undefined) {
	if (!key) return;
	const { s3, bucket } = r2();
	await s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: key })).catch(() => {});
}
