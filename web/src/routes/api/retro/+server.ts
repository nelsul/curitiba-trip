import { json } from '@sveltejs/kit';
import { retro } from '$lib/server/retro';
import type { RequestHandler } from './$types';

/** `{ weddingAt, items }`: the countdown target and the admin's picks (feed media items, in order). */
export const GET: RequestHandler = async () => json(await retro());
