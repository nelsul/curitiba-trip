import { redirect } from '@sveltejs/kit';
import { addComment, deleteComment } from '$lib/server/comments';
import { assertTarget, checkinDetail, deleteCheckin, updateCheckinNote } from '$lib/server/details';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	return checkinDetail(params.id);
};

export const actions: Actions = {
	comentar: async ({ params, request, locals }) => {
		await assertTarget({ checkinId: params.id });
		return addComment(request, locals.user!.id, { checkinId: params.id });
	},
	apagarComentario: ({ request, locals }) => deleteComment(request, locals.user!),
	nota: async ({ params, request, locals }) => {
		await updateCheckinNote(params.id, locals.user!.id, (await request.formData()).get('note') ?? '');
		return { saved: true };
	},
	apagar: async ({ params, locals }) => {
		await deleteCheckin(params.id, locals.user!);
		redirect(303, '/');
	}
};
