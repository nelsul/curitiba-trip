import { error, json } from '@sveltejs/kit';
import { createComment, listComments } from './comments';
import { assertTarget } from './details';
import { json as body } from './validate';

type Target = { mediaId: string } | { checkinId: string };

export async function listFor(target: Target) {
	await assertTarget(target);
	return json(await listComments(target));
}

export async function addFor(target: Target, request: Request, userId: string) {
	await assertTarget(target);
	const { body: text } = await body<{ body?: string }>(request);
	const id = await createComment(userId, target, text);
	if (!id) error(400, 'Escreva alguma coisa.');
	return json((await listComments(target)).find((c) => c.id === id), { status: 201 });
}
