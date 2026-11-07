import postgres from 'postgres';
import { drizzle } from 'drizzle-orm/postgres-js';
import * as schema from '../db/schema';

export function createDb(url: string, max = 10) {
	const client = postgres(url, { max });
	return drizzle(client, { schema });
}
export type Db = ReturnType<typeof createDb>;
