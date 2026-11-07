import { mediaUrl } from '$lib/server/r2';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals }) => {
	const u = locals.user!;
	return { me: { id: u.id, name: u.name, color: u.color, isAdmin: u.isAdmin, photo: await mediaUrl(u.avatarKey) } };
};
