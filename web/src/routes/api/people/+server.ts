import { json } from '@sveltejs/kit';
import { people } from '$lib/server/feed';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async () => json(await people());
