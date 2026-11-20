import { mediaUrl } from '$lib/server/r2';
import { people } from '$lib/server/feed';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals }) => {
	if (locals.guest) {
		// a visitor: no account, reads the Diário until the code ends
		const g = locals.guest;
		return {
			me: { id: '', name: 'Visitante', color: '#888888', isAdmin: false, photo: null as string | null },
			guest: { until: g.expiresAt.toISOString(), by: g.byName },
			persons: await people()
		};
	}
	const u = locals.user!;
	const [photo, persons] = await Promise.all([mediaUrl(u.avatarKey), people()]);
	return { me: { id: u.id, name: u.name, color: u.color, isAdmin: u.isAdmin, photo }, guest: null as { until: string; by: string } | null, persons };
};
