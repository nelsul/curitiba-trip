import { error, json } from '@sveltejs/kit';
import { checkinDetail, deleteCheckin, updateCheckinNote } from '$lib/server/details';
import { json as body } from '$lib/server/validate';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ params }) => json(await checkinDetail(params.id));

/** Owner: `{ note }` */
export const PATCH: RequestHandler = async ({ params, request, locals }) => {
	const { note } = await body<{ note?: string }>(request);
	await updateCheckinNote(params.id, locals.user!.id, note ?? '');
	return json((await checkinDetail(params.id)).item);
};

/** Only the person who checked in can delete it (comments, likes and the map picture go with it). */
export const DELETE: RequestHandler = async ({ params, locals }) => {
	if (!(await deleteCheckin(params.id, locals.user!.id))) error(403, 'Só quem fez o check-in pode apagar.');
	return json({ ok: true });
};
