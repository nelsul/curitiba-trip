import { json } from '@sveltejs/kit';
import { MIN_APP_VERSION, toMe } from '$lib/server/me';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals }) => json({ ...(await toMe(locals.user!)), minAppVersion: MIN_APP_VERSION });
