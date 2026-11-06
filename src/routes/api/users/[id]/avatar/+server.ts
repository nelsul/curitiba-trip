import { error, json } from '@sveltejs/kit';
import { DeleteObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { randomBytes } from 'node:crypto';
import { eq } from 'drizzle-orm';
import { db, users } from '$lib/server/db';
import { mediaUrl, r2 } from '$lib/server/r2';
import type { RequestHandler } from './$types';

const MAX_BYTES = 1024 * 1024; // the browser sends a 512px square, usually ~50 KB

async function target(id: string, locals: App.Locals) {
	if (!/^[0-9a-f-]{36}$/.test(id)) error(404, 'Não encontrado');
	if (locals.user!.id !== id && !locals.user!.isAdmin) error(403, 'Você só pode mudar a sua própria foto.');
	const [u] = await db().select().from(users).where(eq(users.id, id));
	if (!u) error(404, 'Não encontrado');
	return u;
}

/** Detect the image type from its first bytes instead of trusting the header. */
function sniff(b: Uint8Array): { type: string; ext: string } | null {
	if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return { type: 'image/jpeg', ext: 'jpg' };
	if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return { type: 'image/png', ext: 'png' };
	if (String.fromCharCode(...b.slice(0, 4)) === 'RIFF' && String.fromCharCode(...b.slice(8, 12)) === 'WEBP') return { type: 'image/webp', ext: 'webp' };
	return null;
}

async function removeOld(key: string | null) {
	if (!key) return;
	const { s3, bucket } = r2();
	await s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: key })).catch(() => {});
}

export const PUT: RequestHandler = async ({ params, request, locals }) => {
	const u = await target(params.id, locals);
	const body = new Uint8Array(await request.arrayBuffer());
	if (body.length === 0) error(400, 'Imagem vazia.');
	if (body.length > MAX_BYTES) error(413, 'Imagem grande demais.');
	const kind = sniff(body);
	if (!kind) error(415, 'Formato não suportado. Use JPG, PNG ou WebP.');

	// New random key each time: the URL changes, so browsers never show a stale cached photo.
	const key = `avatars/${u.id}/${randomBytes(8).toString('hex')}.${kind.ext}`;
	const { s3, bucket } = r2();
	await s3.send(new PutObjectCommand({ Bucket: bucket, Key: key, Body: body, ContentType: kind.type, CacheControl: 'public, max-age=31536000, immutable' }));
	await db().update(users).set({ avatarKey: key }).where(eq(users.id, u.id));
	await removeOld(u.avatarKey);
	return json({ photo: await mediaUrl(key) });
};

export const DELETE: RequestHandler = async ({ params, locals }) => {
	const u = await target(params.id, locals);
	await db().update(users).set({ avatarKey: null }).where(eq(users.id, u.id));
	await removeOld(u.avatarKey);
	return json({ photo: null });
};
