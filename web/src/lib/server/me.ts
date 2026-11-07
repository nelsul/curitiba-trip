import type { User } from './db';
import { mediaUrl } from './r2';

/** Lowest iOS app build allowed to talk to this API; older builds show "fale com o Nelson para atualizar". */
export const MIN_APP_VERSION = '0.1.0';

export type Me = { id: string; name: string; color: string; photo: string | null; isAdmin: boolean };

export async function toMe(u: User): Promise<Me> {
	return { id: u.id, name: u.name, color: u.color, photo: await mediaUrl(u.avatarKey), isAdmin: u.isAdmin };
}
