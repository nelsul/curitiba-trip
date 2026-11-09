import { json } from '@sveltejs/kit';
import { unseenCoupleLikes } from '$lib/server/couple';
import type { RequestHandler } from './$types';

/** Likes from the bride/groom on my posts that I haven't seen the special effect for. */
export const GET: RequestHandler = async ({ locals }) => json({ likes: await unseenCoupleLikes(locals.user!.id) });
