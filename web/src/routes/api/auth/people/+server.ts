import { json } from '@sveltejs/kit';
import { people } from '$lib/server/feed';
import type { RequestHandler } from './$types';

/** Public: the "Quem é você?" list (no emails). */
export const GET: RequestHandler = async () => json(await people());
