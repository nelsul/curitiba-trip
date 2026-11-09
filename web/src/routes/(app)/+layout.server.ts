import { mediaUrl } from '$lib/server/r2';
import { people } from '$lib/server/feed';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals }) => {
	const u = locals.user!;
	const [photo, persons] = await Promise.all([mediaUrl(u.avatarKey), people()]);
	return { me: { id: u.id, name: u.name, color: u.color, isAdmin: u.isAdmin, photo }, persons };
};
