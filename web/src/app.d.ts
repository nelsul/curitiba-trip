import type { SessionKind, User } from '$lib/server/db/schema';
import type { Guest } from '$lib/server/guest';

declare global {
	namespace App {
		interface Locals {
			user: User | null;
			/** current session (sha256 id), used for logout and the devices list */
			session: { id: string; kind: SessionKind } | null;
			/** a visitor with a code (no account): may only read the Diário */
			guest: Guest | null;
		}
	}
}

export {};
