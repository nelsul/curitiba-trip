import { fail } from '@sveltejs/kit';
import { asc, eq, sql } from 'drizzle-orm';
import { db, users } from '$lib/server/db';
import { normalizeEmail } from '$lib/server/auth';
import { clip } from '$lib/server/validate';
import { mediaUrl, r2 } from '$lib/server/r2';
import { DeleteObjectCommand } from '@aws-sdk/client-s3';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async () => {
	const rows = await db().execute<{ id: string; name: string; email: string; color: string; is_admin: boolean; couple: string | null; avatar_key: string | null; items: number }>(sql`
		select u.id, u.name, u.email, u.color, u.is_admin, u.couple, u.avatar_key,
			(select count(*) from media m where m.user_id = u.id)::int + (select count(*) from checkins c where c.user_id = u.id)::int as items
		from users u order by u.name`);
	return { users: await Promise.all([...rows].map(async ({ avatar_key, ...u }) => ({ ...u, photo: await mediaUrl(avatar_key) }))) };
};

const COLOR = /^#[0-9a-fA-F]{6}$/;

export const actions: Actions = {
	adicionar: async ({ request }) => {
		const f = await request.formData();
		const name = clip(f.get('name'), 60);
		const email = normalizeEmail(String(f.get('email') ?? ''));
		const color = String(f.get('color') ?? '');
		if (!name || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return fail(400, { error: 'Nome e e-mail válidos, por favor.' });
		const [exists] = await db().select({ id: users.id }).from(users).where(eq(users.email, email));
		if (exists) return fail(400, { error: 'Esse e-mail já está na lista.' });
		await db().insert(users).values({ name, email, color: COLOR.test(color) ? color : '#2F5A40' });
		return { added: name };
	},
	editar: async ({ request }) => {
		const f = await request.formData();
		const id = String(f.get('id') ?? '');
		const name = clip(f.get('name'), 60);
		const color = String(f.get('color') ?? '');
		if (!name || !COLOR.test(color)) return fail(400, { error: 'Dados inválidos.' });
		await db().update(users).set({ name, color }).where(eq(users.id, id));
		return { saved: true };
	},
	noivos: async ({ request }) => {
		const f = await request.formData();
		const id = String(f.get('id') ?? '');
		const v = String(f.get('couple') ?? '');
		await db().update(users).set({ couple: v === 'noivo' || v === 'noiva' ? v : null }).where(eq(users.id, id));
		return { saved: true };
	},
	remover: async ({ request, locals }) => {
		const id = String((await request.formData()).get('id') ?? '');
		if (id === locals.user!.id) return fail(400, { error: 'Você não pode se remover.' });
		const [target] = await db().select({ avatarKey: users.avatarKey }).from(users).where(eq(users.id, id));
		const [{ n }] = await db().execute<{ n: number }>(
			sql`select ((select count(*) from media where user_id = ${id}) + (select count(*) from checkins where user_id = ${id}))::int as n`
		);
		if (n > 0) return fail(400, { error: 'Essa pessoa já enviou coisas; não dá para remover.' });
		await db().delete(users).where(eq(users.id, id));
		if (target?.avatarKey) {
			const { s3, bucket } = r2();
			await s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: target.avatarKey })).catch(() => {});
		}
		return { removed: true };
	}
};
