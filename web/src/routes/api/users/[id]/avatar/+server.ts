import { error, json } from '@sveltejs/kit';
import { eq } from 'drizzle-orm';
import { db, users } from '$lib/server/db';
import { mediaUrl } from '$lib/server/r2';
import { deleteObject, putImage, sniffImage } from '$lib/server/images';
import type { RequestHandler } from './$types';

const MAX_BYTES = 1024 * 1024; // the browser sends a 512px square, usually ~50 KB

async function target(id: string, locals: App.Locals) {
	if (!/^[0-9a-f-]{36}$/.test(id)) error(404, 'Não encontrado');
	if (locals.user!.id !== id && !locals.user!.isAdmin) error(403, 'Você só pode mudar a sua própria foto.');
	const [u] = await db().select().from(users).where(eq(users.id, id));
	if (!u) error(404, 'Não encontrado');
	return u;
}

export const PUT: RequestHandler = async ({ params, request, locals }) => {
	const u = await target(params.id, locals);
	const body = new Uint8Array(await request.arrayBuffer());
	if (body.length === 0) error(400, 'Imagem vazia.');
	if (body.length > MAX_BYTES) error(413, 'Imagem grande demais.');
	const kind = sniffImage(body);
	if (!kind) error(415, 'Formato não suportado. Use JPG, PNG ou WebP.');
	const key = await putImage(`avatars/${u.id}`, body, kind);
	await db().update(users).set({ avatarKey: key }).where(eq(users.id, u.id));
	await deleteObject(u.avatarKey);
	return json({ photo: await mediaUrl(key) });
};

export const DELETE: RequestHandler = async ({ params, locals }) => {
	const u = await target(params.id, locals);
	await db().update(users).set({ avatarKey: null }).where(eq(users.id, u.id));
	await deleteObject(u.avatarKey);
	return json({ photo: null });
};
