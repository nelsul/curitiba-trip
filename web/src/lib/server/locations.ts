import { sql } from 'drizzle-orm';
import { db } from './db';
import { mediaUrl } from './r2';

export type LatestLocation = { userId: string; name: string; color: string; photo: string | null; lat: number; lng: number; at: string };

/** Last known position per person (latest of live pings and check-ins). */
export async function latestLocations(): Promise<LatestLocation[]> {
	const rows = await db().execute<{ user_id: string; name: string; color: string; avatar_key: string | null; lat: number; lng: number; at: Date }>(sql`
		select distinct on (p.user_id) p.user_id, u.name, u.color, u.avatar_key, p.lat, p.lng, p.created_at as at
		from location_pings p join users u on u.id = p.user_id
		order by p.user_id, p.created_at desc`);
	return Promise.all(
		rows.map(async (r) => ({
			userId: r.user_id,
			name: r.name,
			color: r.color,
			photo: await mediaUrl(r.avatar_key),
			lat: r.lat,
			lng: r.lng,
			at: new Date(r.at).toISOString()
		}))
	);
}
