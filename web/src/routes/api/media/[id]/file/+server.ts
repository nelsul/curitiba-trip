import { error } from '@sveltejs/kit';
import { GetObjectCommand } from '@aws-sdk/client-s3';
import { eq } from 'drizzle-orm';
import { db, media } from '$lib/server/db';
import { r2 } from '$lib/server/r2';
import type { RequestHandler } from './$types';

/**
 * The feed-size picture of a photo (or a video's poster), served from our own origin so the website can draw it
 * on a canvas (the share frames). Presigned R2 URLs would taint the canvas.
 */
export const GET: RequestHandler = async ({ params }) => {
	if (!/^[0-9a-f-]{36}$/.test(params.id)) error(404, 'Não encontrado');
	const [m] = await db().select({ medium: media.mediumKey, display: media.displayKey, poster: media.posterKey }).from(media).where(eq(media.id, params.id));
	const key = m?.medium ?? m?.display ?? m?.poster;
	if (!key) error(404, 'Não encontrado');
	const { s3, bucket } = r2();
	const obj = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key })).catch((e) => {
		if ((e as Error).name === 'NoSuchKey') error(404, 'Não encontrado');
		throw e;
	});
	return new Response(obj.Body!.transformToWebStream(), {
		headers: { 'content-type': obj.ContentType ?? 'image/jpeg', 'cache-control': 'private, max-age=86400' }
	});
};
