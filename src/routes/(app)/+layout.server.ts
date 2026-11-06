import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = ({ locals }) => ({
	me: { id: locals.user!.id, name: locals.user!.name, color: locals.user!.color, isAdmin: locals.user!.isAdmin }
});
