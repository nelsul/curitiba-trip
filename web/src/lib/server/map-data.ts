import { and, asc, gte, lt } from 'drizzle-orm';
import { db, locationPings } from './db';
import { feed } from './feed';
import { latestLocations } from './locations';
import { dayKey } from '$lib/format';

/** Everything the map shows: located posts and check-ins, location trails, and everyone's latest position. */
export async function mapData(day?: string | null) {
	// Curitiba is UTC-3 all year, so a local day is [day 03:00Z, next day 03:00Z)
	const range = day ? [new Date(`${day}T00:00:00-03:00`), new Date(new Date(`${day}T00:00:00-03:00`).getTime() + 86_400_000)] : null;
	const [items, pings, latest] = await Promise.all([
		feed(),
		db()
			.select({ userId: locationPings.userId, lat: locationPings.lat, lng: locationPings.lng, at: locationPings.createdAt })
			.from(locationPings)
			.where(range ? and(gte(locationPings.createdAt, range[0]), lt(locationPings.createdAt, range[1])) : undefined)
			.orderBy(asc(locationPings.createdAt)),
		latestLocations()
	]);
	return {
		items: items.filter((i) => i.lat != null && i.lng != null && (!day || i.day === day)),
		pings: pings.map((p) => ({ userId: p.userId, lat: p.lat, lng: p.lng, at: p.at.toISOString(), day: dayKey(p.at) })),
		latest
	};
}
