import { env } from '$env/dynamic/private';
import { createDb, type Db } from '../shared/db';

let _db: Db | undefined;
export function db(): Db {
	if (!_db) {
		if (!env.DATABASE_URL) throw new Error('DATABASE_URL is not set');
		_db = createDb(env.DATABASE_URL);
	}
	return _db;
}
export * from './schema';
