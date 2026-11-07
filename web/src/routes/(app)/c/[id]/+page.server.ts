import { redirect } from '@sveltejs/kit';
import { addComment, deleteComment } from '$lib/server/comments';
import { assertTarget, checkinDetail, deleteCheckin, updateCheckinNote } from '$lib/server/details';
import { people } from '$lib/server/feed';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	const [detail, persons] = await Promise.all([checkinDetail(params.id), people()]);
	return { ...detail, persons };
};

export const actions: Actions = {
	comentar: async ({ params, request, locals }) => {
		await assertTarget({ checkinId: params.id });
		return addComment(request, locals.user!.id, { checkinId: params.id });
	},
	apagarComentario: ({ request, locals }) => deleteComment(request, locals.user!.id),
	nota: async ({ params, request, locals }) => {
		await updateCheckinNote(params.id, locals.user!.id, (await request.formData()).get('note') ?? '');
		return { saved: true };
	},
	apagar: async ({ params, locals }) => {
		await deleteCheckin(params.id, locals.user!.id);
		redirect(303, '/');
	}
};
