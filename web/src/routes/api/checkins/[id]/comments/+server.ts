import { addFor, listFor } from '$lib/server/comment-api';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ params }) => listFor({ checkinId: params.id });
/** `{ body }` → the new comment */
export const POST: RequestHandler = ({ params, request, locals }) => addFor({ checkinId: params.id }, request, locals.user!.id);
