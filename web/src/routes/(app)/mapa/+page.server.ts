import { asc } from 'drizzle-orm';
import { db, locationPings } from '$lib/server/db';
import { feed, people } from '$lib/server/feed';
import { latestLocations } from '$lib/server/locations';
import { dayKey } from '$lib/format';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ depends }) => {
	depends('app:feed');
	const [items, persons, pings, latest] = await Promise.all([
		feed(),
		people(),
		db()
			.select({ userId: locationPings.userId, lat: locationPings.lat, lng: locationPings.lng, at: locationPings.createdAt })
			.from(locationPings)
			.orderBy(asc(locationPings.createdAt)),
		latestLocations()
	]);
	return {
		persons,
		items: items.filter((i) => i.lat != null && i.lng != null),
		pings: pings.map((p) => ({ userId: p.userId, lat: p.lat, lng: p.lng, at: p.at.toISOString(), day: dayKey(p.at) })),
		latest
	};
};
