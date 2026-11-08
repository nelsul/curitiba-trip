import { feed } from './feed';
import { latestLocations } from './locations';

/**
 * Everything the map shows: located posts and check-ins, and everyone's latest position.
 * `pings` (location trails) is always empty: trails were removed because background positions
 * weren't reliable enough. The field stays so installed apps keep decoding the response.
 */
export async function mapData(day?: string | null) {
	const [items, latest] = await Promise.all([feed(), latestLocations()]);
	return {
		items: items.filter((i) => i.lat != null && i.lng != null && (!day || i.day === day)),
		pings: [] as { userId: string; lat: number; lng: number; at: string; day: string }[],
		latest
	};
}
