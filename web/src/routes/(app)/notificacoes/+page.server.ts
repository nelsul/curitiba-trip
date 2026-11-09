import { notifications } from '$lib/server/notifications';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, depends }) => {
	depends('app:notificacoes');
	return notifications(locals.user!.id);
};
