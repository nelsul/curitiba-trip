import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

/** The Galeria moved into the Diário ("Todas as fotos", and the reels when you tap a post). */
export const load: PageServerLoad = async () => redirect(307, '/?modo=grade');
