import type { SessionKind, User } from '$lib/server/db/schema';

declare global {
	namespace App {
		interface Locals {
			user: User | null;
			/** current session (sha256 id), used for logout and the devices list */
			session: { id: string; kind: SessionKind } | null;
		}
	}
}

export {};
