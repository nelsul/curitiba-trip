import { error, redirect } from '@sveltejs/kit';
import { and, eq } from 'drizzle-orm';
import { checkins, db, users } from '$lib/server/db';
import { addComment, deleteComment, listComments } from '$lib/server/comments';
import { likersOf } from '$lib/server/likes';
import { people } from '$lib/server/feed';
import { clip } from '$lib/server/validate';
import { mediaUrl } from '$lib/server/r2';
import type { Actions, PageServerLoad } from './$types';

async function getCheckin(id: string) {
	if (!/^[0-9a-f-]{36}$/.test(id)) error(404, 'Não encontrado');
	const [row] = await db()
		.select({ c: checkins, name: users.name, color: users.color, avatarKey: users.avatarKey })
		.from(checkins)
		.innerJoin(users, eq(users.id, checkins.userId))
		.where(eq(checkins.id, id));
	if (!row) error(404, 'Não encontrado');
	return row;
}

export const load: PageServerLoad = async ({ params }) => {
	const { c, name, color, avatarKey } = await getCheckin(params.id);
	return {
		item: { id: c.id, userId: c.userId, name, color, photo: await mediaUrl(avatarKey), lat: c.lat, lng: c.lng, note: c.note, at: c.createdAt.toISOString() },
		comments: await listComments({ checkinId: c.id }),
		likers: await likersOf({ checkinId: c.id }),
		persons: await people()
	};
};

export const actions: Actions = {
	comentar: async ({ params, request, locals }) => {
		await getCheckin(params.id);
		return addComment(request, locals.user!.id, { checkinId: params.id });
	},
	apagarComentario: ({ request, locals }) => deleteComment(request, locals.user!.id),
	nota: async ({ params, request, locals }) => {
		const note = clip((await request.formData()).get('note'), 2000);
		await db().update(checkins).set({ note }).where(and(eq(checkins.id, params.id), eq(checkins.userId, locals.user!.id)));
		return { saved: true };
	},
	apagar: async ({ params, locals }) => {
		await db().delete(checkins).where(and(eq(checkins.id, params.id), eq(checkins.userId, locals.user!.id)));
		redirect(303, '/');
	}
};
