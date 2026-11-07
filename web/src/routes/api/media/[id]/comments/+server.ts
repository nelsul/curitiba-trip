import { addFor, listFor } from '$lib/server/comment-api';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ params }) => listFor({ mediaId: params.id });
/** `{ body }` → the new comment */
export const POST: RequestHandler = ({ params, request, locals }) => addFor({ mediaId: params.id }, request, locals.user!.id);
