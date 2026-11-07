import { error } from '@sveltejs/kit';

export const isLat = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v) && v >= -90 && v <= 90;
export const isLng = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v) && v >= -180 && v <= 180;

export async function json<T = Record<string, unknown>>(request: Request): Promise<T> {
	try {
		return (await request.json()) as T;
	} catch {
		error(400, 'JSON inválido');
	}
}

export const clip = (s: unknown, max: number) => (typeof s === 'string' ? s.trim().slice(0, max) : '');
