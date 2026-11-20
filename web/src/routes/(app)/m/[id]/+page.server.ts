import { fail, redirect } from '@sveltejs/kit';
import { addComment, deleteComment } from '$lib/server/comments';
import { assertTarget, deleteMedia, mediaDetail, updateMedia } from '$lib/server/details';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params, depends, locals }) => {
	depends('app:media');
	const d = await mediaDetail(params.id);
	// visitors: no location (no map for them) and no original file
	return locals.guest ? { ...d, item: { ...d.item, lat: null, lng: null, locationSource: null, original: null } } : d;
};

export const actions: Actions = {
	comentar: async ({ params, request, locals }) => {
		await assertTarget({ mediaId: params.id });
		return addComment(request, locals.user!.id, { mediaId: params.id });
	},
	apagarComentario: ({ request, locals }) => deleteComment(request, locals.user!),
	legenda: async ({ params, request, locals }) => {
		await updateMedia(params.id, locals.user!.id, { caption: (await request.formData()).get('caption') ?? '' });
		return { saved: true };
	},
	local: async ({ params, request, locals }) => {
		const f = await request.formData();
		const lat = Number(f.get('lat'));
		const lng = Number(f.get('lng'));
		if (!(Math.abs(lat) <= 90 && Math.abs(lng) <= 180)) return fail(400, { locError: 'Local inválido.' });
		await updateMedia(params.id, locals.user!.id, { lat, lng });
		return { saved: true };
	},
	apagar: async ({ params, locals }) => {
		await deleteMedia(params.id, locals.user!);
		redirect(303, '/');
	}
};
