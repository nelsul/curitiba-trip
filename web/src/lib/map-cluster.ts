/**
 * Groups map points that would overlap on screen, so the map draws a few dozen markers instead of every photo.
 * Greedy and stable: points go newest first, and each one joins the first group whose seed is within `radius`
 * screen pixels at this zoom; otherwise it seeds a new group. The iOS and Android maps use the same rules
 * (TripMap.swift / TripMap.kt), so the three look alike.
 */
export const CLUSTER_RADIUS_PX = 64;
/** From this zoom on, every point gets its own marker. */
export const CLUSTER_MAX_ZOOM = 18;

export type Bounds = { west: number; south: number; east: number; north: number };
export type Cluster<T> = { key: string; lat: number; lng: number; items: T[] };

/** Web-Mercator world pixels at `zoom` (512 px tiles, like MapLibre on the web, iOS and Android). */
export function project(lat: number, lng: number, zoom: number) {
	const scale = 512 * 2 ** zoom;
	const s = Math.sin((Math.max(-85, Math.min(85, lat)) * Math.PI) / 180);
	return { x: ((lng + 180) / 360) * scale, y: (0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)) * scale };
}

export function cluster<T extends { id: string; lat: number; lng: number; at: string }>(
	points: T[],
	zoom: number,
	bounds?: Bounds,
	radius = CLUSTER_RADIUS_PX
): Cluster<T>[] {
	const z = Math.floor(zoom);
	const inView = bounds
		? points.filter((p) => p.lat >= bounds.south && p.lat <= bounds.north && p.lng >= bounds.west && p.lng <= bounds.east)
		: points;
	const sorted = [...inView].sort((a, b) => b.at.localeCompare(a.at) || b.id.localeCompare(a.id));
	if (z >= CLUSTER_MAX_ZOOM) return sorted.map((p) => ({ key: p.id, lat: p.lat, lng: p.lng, items: [p] }));

	const out: (Cluster<T> & { x: number; y: number })[] = [];
	const grid = new Map<string, number[]>();
	for (const p of sorted) {
		const { x, y } = project(p.lat, p.lng, z);
		const cx = Math.floor(x / radius), cy = Math.floor(y / radius);
		let found = -1;
		for (let dx = -1; dx <= 1 && found < 0; dx++)
			for (let dy = -1; dy <= 1 && found < 0; dy++)
				for (const i of grid.get(`${cx + dx}:${cy + dy}`) ?? [])
					if (Math.hypot(out[i].x - x, out[i].y - y) <= radius) {
						found = i;
						break;
					}
		if (found >= 0) out[found].items.push(p);
		else {
			const k = `${cx}:${cy}`;
			(grid.get(k) ?? grid.set(k, []).get(k)!).push(out.length);
			out.push({ key: p.id, lat: p.lat, lng: p.lng, x, y, items: [p] });
		}
	}
	return out.map(({ key, lat, lng, items }) => ({ key: items.length > 1 ? `${key}+${items.length}` : key, lat, lng, items }));
}

/** Pads bounds by a fraction of their size, so markers just off-screen are ready when the map pans. */
export function padBounds(b: Bounds, f = 0.25): Bounds {
	const w = (b.east - b.west) * f, h = (b.north - b.south) * f;
	return { west: b.west - w, south: b.south - h, east: b.east + w, north: b.north + h };
}
