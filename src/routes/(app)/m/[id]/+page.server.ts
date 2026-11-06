import { error, fail, redirect } from '@sveltejs/kit';
import { DeleteObjectsCommand } from '@aws-sdk/client-s3';
import { and, eq } from 'drizzle-orm';
import { db, media, users } from '$lib/server/db';
import { mediaUrl, r2 } from '$lib/server/r2';
import { addComment, deleteComment, listComments } from '$lib/server/comments';
import { clip } from '$lib/server/validate';
import type { Actions, PageServerLoad } from './$types';

async function getMedia(id: string) {
	if (!/^[0-9a-f-]{36}$/.test(id)) error(404, 'Não encontrado');
	const [row] = await db()
		.select({ m: media, name: users.name, color: users.color })
		.from(media)
		.innerJoin(users, eq(users.id, media.userId))
		.where(eq(media.id, id));
	if (!row || row.m.status === 'uploading') error(404, 'Não encontrado');
	return row;
}

export const load: PageServerLoad = async ({ params, depends }) => {
	depends('app:media');
	const { m, name, color } = await getMedia(params.id);
	const [display, video, poster, original, comments] = await Promise.all([
		mediaUrl(m.displayKey),
		mediaUrl(m.videoKey),
		mediaUrl(m.posterKey),
		mediaUrl(m.originalKey, m.originalName),
		listComments({ mediaId: m.id })
	]);
	return {
		item: {
			id: m.id,
			userId: m.userId,
			name,
			color,
			kind: m.kind,
			status: m.status,
			error: m.error,
			at: (m.takenAt ?? m.createdAt).toISOString(),
			takenAtSource: m.takenAtSource,
			lat: m.lat,
			lng: m.lng,
			locationSource: m.locationSource,
			width: m.width,
			height: m.height,
			durationS: m.durationS,
			sizeBytes: m.sizeBytes,
			originalName: m.originalName,
			caption: m.caption,
			display,
			video,
			poster,
			original
		},
		comments
	};
};

async function owned(id: string, userId: string) {
	const { m } = await getMedia(id);
	if (m.userId !== userId) error(403, 'Só quem enviou pode mudar isso.');
	return m;
}

export const actions: Actions = {
	comentar: async ({ params, request, locals }) => {
		await getMedia(params.id);
		return addComment(request, locals.user!.id, { mediaId: params.id });
	},
	apagarComentario: ({ request, locals }) => deleteComment(request, locals.user!.id),
	legenda: async ({ params, request, locals }) => {
		const m = await owned(params.id, locals.user!.id);
		const caption = clip((await request.formData()).get('caption'), 2000);
		await db().update(media).set({ caption }).where(eq(media.id, m.id));
		return { saved: true };
	},
	local: async ({ params, request, locals }) => {
		const m = await owned(params.id, locals.user!.id);
		const f = await request.formData();
		const lat = Number(f.get('lat'));
		const lng = Number(f.get('lng'));
		if (!(Math.abs(lat) <= 90 && Math.abs(lng) <= 180)) return fail(400, { locError: 'Local inválido.' });
		await db().update(media).set({ lat, lng, locationSource: 'manual' }).where(eq(media.id, m.id));
		return { saved: true };
	},
	apagar: async ({ params, locals }) => {
		const m = await owned(params.id, locals.user!.id);
		const keys = [m.originalKey, m.displayKey, m.thumbKey, m.posterKey, m.videoKey].filter(Boolean) as string[];
		const { s3, bucket } = r2();
		await s3.send(new DeleteObjectsCommand({ Bucket: bucket, Delete: { Objects: keys.map((Key) => ({ Key })) } }));
		await db().delete(media).where(and(eq(media.id, m.id), eq(media.userId, locals.user!.id)));
		redirect(303, '/');
	}
};
