import { error } from '@sveltejs/kit';
import { asc, eq, inArray } from 'drizzle-orm';
import { randomBytes } from 'node:crypto';
import { db, itineraryDays, itineraryStops, placePhotos, places } from './db';
import { mediaUrl } from './r2';
import { deleteObject } from './images';
import { clip, isLat, isLng } from './validate';
import {
	CATEGORY,
	TRANSPORT,
	placeUrl,
	routeUrl,
	uberUrl,
	type PlaceCategory,
	type RoteiroDay,
	type RoteiroPlace,
	type Transport
} from '$lib/itinerary';

// ── reading ──

export async function listPlaces(): Promise<RoteiroPlace[]> {
	const [rows, photos] = await Promise.all([
		db().select().from(places).orderBy(asc(places.name)),
		db().select().from(placePhotos).orderBy(asc(placePhotos.createdAt))
	]);
	const byPlace = new Map<string, { id: string; key: string }[]>();
	for (const p of photos) (byPlace.get(p.placeId) ?? byPlace.set(p.placeId, []).get(p.placeId)!).push(p);
	return Promise.all(
		rows.map(async (p) => ({
			id: p.id,
			name: p.name,
			category: p.category,
			lat: p.lat,
			lng: p.lng,
			address: p.address,
			hours: p.hours,
			price: p.price,
			priceLevel: p.priceLevel,
			description: p.description,
			link: p.link,
			googlePlaceId: p.googlePlaceId,
			photos: await Promise.all((byPlace.get(p.id) ?? []).map(async (ph) => ({ id: ph.id, url: (await mediaUrl(ph.key))! })))
		}))
	);
}

export async function listDays(): Promise<RoteiroDay[]> {
	const [days, stops] = await Promise.all([
		db().select().from(itineraryDays).orderBy(asc(itineraryDays.date)),
		db().select().from(itineraryStops).orderBy(asc(itineraryStops.day), asc(itineraryStops.position))
	]);
	return days.map((d) => ({
		date: d.date,
		title: d.title,
		who: d.who,
		lead: d.lead,
		wedding: d.wedding,
		stops: stops
			.filter((s) => s.day === d.date)
			.map((s) => ({
				id: s.id,
				time: s.time,
				placeId: s.placeId,
				label: s.label,
				transport: s.transport,
				note: s.note,
				visitedAt: s.visitedAt?.toISOString() ?? null,
				visitedBy: s.visitedBy
			}))
	}));
}

/** GET /api/itinerary: the shape the iPhone and Android apps already read (reminders, arrival areas, Roteiro). */
export async function itineraryForApps() {
	const [days, all] = await Promise.all([listDays(), listPlaces()]);
	const byId = new Map(all.map((p) => [p.id, p]));
	return {
		transport: Object.fromEntries(Object.entries(TRANSPORT).map(([k, v]) => [k, { label: v.label }])),
		days: days.map((d) => {
			const stopPlaces = d.stops.map((s) => (s.placeId ? byId.get(s.placeId) : undefined));
			return {
				date: d.date,
				title: d.title,
				who: d.who,
				lead: d.lead,
				wedding: d.wedding,
				routeUrl: routeUrl(stopPlaces.filter((p) => !!p)),
				stops: d.stops.map((s, i) => {
					const p = stopPlaces[i];
					return {
						time: s.time,
						visited: !!s.visitedAt,
						transport: s.transport,
						note: s.note,
						title: p?.name ?? s.label,
						place: p
							? {
									id: p.id,
									name: p.name,
									lat: p.lat,
									lng: p.lng,
									hours: p.hours,
									placeId: p.googlePlaceId ?? '',
									category: p.category,
									price: p.price,
									photo: p.photos[0]?.url ?? null,
									mapsUrl: placeUrl(p),
									uberUrl: uberUrl(p)
								}
							: null
					};
				})
			};
		})
	};
}

// ── places ──

const str = (b: Record<string, unknown>, k: string, max: number) => clip(b[k], max);

function placeInput(b: Record<string, unknown>) {
	const name = str(b, 'name', 120);
	if (!name) error(400, 'Dê um nome ao lugar.');
	const lat = Number(b.lat), lng = Number(b.lng);
	if (!isLat(lat) || !isLng(lng)) error(400, 'Marque o lugar no mapa.');
	const category = (typeof b.category === 'string' && b.category in CATEGORY ? b.category : 'passeio') as PlaceCategory;
	const level = b.priceLevel === null || b.priceLevel === '' || b.priceLevel === undefined ? null : Number(b.priceLevel);
	if (level !== null && !(Number.isInteger(level) && level >= 0 && level <= 4)) error(400, 'Faixa de preço inválida.');
	let link = str(b, 'link', 500);
	if (link && !/^https?:\/\//i.test(link)) link = `https://${link}`;
	if (link) {
		try {
			new URL(link);
		} catch {
			error(400, 'Link inválido.');
		}
	}
	return {
		name,
		category,
		lat,
		lng,
		address: str(b, 'address', 200),
		hours: str(b, 'hours', 300),
		price: str(b, 'price', 120),
		priceLevel: level,
		description: str(b, 'description', 2000),
		link
	};
}

export async function createPlace(b: Record<string, unknown>, userId: string) {
	const id = randomBytes(6).toString('hex');
	await db().insert(places).values({ id, ...placeInput(b), createdBy: userId });
	return id;
}

export async function updatePlace(id: string, b: Record<string, unknown>) {
	const r = await db().update(places).set({ ...placeInput(b), updatedAt: new Date() }).where(eq(places.id, id)).returning({ id: places.id });
	if (!r.length) error(404, 'Lugar não encontrado.');
}

/** Deletes a place and its photos. Stops that used it keep the name as plain text. */
export async function deletePlace(id: string) {
	const [p] = await db().select().from(places).where(eq(places.id, id));
	if (!p) error(404, 'Lugar não encontrado.');
	const photos = await db().select().from(placePhotos).where(eq(placePhotos.placeId, id));
	await db().transaction(async (tx) => {
		await tx.update(itineraryStops).set({ placeId: null, label: p.name }).where(eq(itineraryStops.placeId, id));
		await tx.delete(places).where(eq(places.id, id));
	});
	await Promise.all(photos.map((ph) => deleteObject(ph.key)));
}

export async function placeExists(id: string) {
	const [p] = await db().select({ id: places.id }).from(places).where(eq(places.id, id));
	return !!p;
}

// ── days ──

const DATE = /^\d{4}-\d{2}-\d{2}$/;

export function checkDate(date: string) {
	if (!DATE.test(date) || Number.isNaN(Date.parse(`${date}T12:00:00Z`))) error(400, 'Data inválida.');
}

/**
 * Saves a whole day (its texts and the ordered stops), replacing what was there. Stops sent with their `id`
 * keep it, and keep their "Fomos!" tick.
 */
export async function saveDay(date: string, b: Record<string, unknown>, userId: string) {
	checkDate(date);
	const rawStops = Array.isArray(b.stops) ? (b.stops as Record<string, unknown>[]) : [];
	if (rawStops.length > 30) error(400, 'Paradas demais para um dia.');
	const stops = rawStops.map((s, i) => {
		const placeId = typeof s.placeId === 'string' && s.placeId ? s.placeId : null;
		const label = str(s, 'label', 120);
		if (!placeId && !label) error(400, `Parada ${i + 1}: escolha um lugar ou escreva o que é.`);
		const transport = (typeof s.transport === 'string' && s.transport in TRANSPORT ? s.transport : 'pe') as Transport;
		const id = typeof s.id === 'string' && /^[0-9a-f-]{36}$/.test(s.id) ? s.id : undefined;
		return { id, day: date, position: i, time: str(s, 'time', 40), placeId, label, transport, note: str(s, 'note', 1000) };
	});
	const ids = [...new Set(stops.map((s) => s.placeId).filter((x): x is string => !!x))];
	if (ids.length) {
		const found = await db().select({ id: places.id }).from(places).where(inArray(places.id, ids));
		if (found.length !== ids.length) error(400, 'Um dos lugares não existe mais. Recarregue a página.');
	}
	const day = {
		title: str(b, 'title', 120),
		who: str(b, 'who', 300),
		lead: str(b, 'lead', 1000),
		wedding: b.wedding === true,
		updatedBy: userId,
		updatedAt: new Date()
	};
	await db().transaction(async (tx) => {
		await tx.insert(itineraryDays).values({ date, ...day }).onConflictDoUpdate({ target: itineraryDays.date, set: day });
		// only this day's own stops keep their id and tick (ids from elsewhere get new ones)
		const before = await tx
			.select({ id: itineraryStops.id, visitedAt: itineraryStops.visitedAt, visitedBy: itineraryStops.visitedBy })
			.from(itineraryStops)
			.where(eq(itineraryStops.day, date));
		const kept = new Map(before.map((b) => [b.id, b]));
		await tx.delete(itineraryStops).where(eq(itineraryStops.day, date));
		if (stops.length)
			await tx.insert(itineraryStops).values(
				stops.map(({ id, ...s }) => {
					const old = id ? kept.get(id) : undefined;
					return old ? { id, ...s, visitedAt: old.visitedAt, visitedBy: old.visitedBy } : s;
				})
			);
	});
}

/** "Fomos!": one person ticks a stop for the whole group (or unticks it). */
export async function setVisited(stopId: string, visited: boolean, userId: string) {
	if (!/^[0-9a-f-]{36}$/.test(stopId)) error(404, 'Parada não encontrada.');
	const r = await db()
		.update(itineraryStops)
		.set(visited ? { visitedAt: new Date(), visitedBy: userId } : { visitedAt: null, visitedBy: null })
		.where(eq(itineraryStops.id, stopId))
		.returning({ visitedAt: itineraryStops.visitedAt, visitedBy: itineraryStops.visitedBy });
	if (!r.length) error(404, 'Parada não encontrada. Recarregue a página.');
	return { visitedAt: r[0].visitedAt?.toISOString() ?? null, visitedBy: r[0].visitedBy };
}

export async function deleteDay(date: string) {
	checkDate(date);
	await db().delete(itineraryDays).where(eq(itineraryDays.date, date));
}

// ── route on the map ──

type Leg = { coordinates: [number, number][]; routed: boolean };
const legCache = new Map<string, { at: number; leg: Leg }>();

/**
 * Street route between two points from the FOSSGIS OSRM servers (OpenStreetMap data, free): on foot for walking
 * legs, by car for everything else. Falls back to a straight line if the router doesn't answer.
 */
async function routeLeg(a: [number, number], b: [number, number], foot: boolean): Promise<Leg> {
	const key = `${foot ? 'f' : 'c'}|${a.map((x) => x.toFixed(5))}|${b.map((x) => x.toFixed(5))}`;
	const hit = legCache.get(key);
	if (hit && Date.now() - hit.at < 7 * 86_400_000) return hit.leg;
	let leg: Leg = { coordinates: [a, b], routed: false };
	try {
		const url = `https://routing.openstreetmap.de/routed-${foot ? 'foot' : 'car'}/route/v1/driving/${a.join(',')};${b.join(',')}?overview=full&geometries=geojson`;
		const r = await fetch(url, {
			headers: { 'user-agent': 'curitiba-trip/1.0 (+https://github.com/nelsul/curitiba-trip)' },
			signal: AbortSignal.timeout(8000)
		});
		if (r.ok) {
			const body = (await r.json()) as { code: string; routes?: { geometry: { coordinates: [number, number][] } }[] };
			const coords = body.routes?.[0]?.geometry.coordinates;
			if (body.code === 'Ok' && coords?.length) leg = { coordinates: coords, routed: true };
		}
	} catch {
		// straight line
	}
	if (legCache.size > 2000) legCache.clear();
	if (leg.routed) legCache.set(key, { at: Date.now(), leg });
	return leg;
}

/** The day's route, one leg per pair of consecutive stops that have places. */
export async function dayRoute(date: string) {
	checkDate(date);
	const rows = await db()
		.select({ transport: itineraryStops.transport, lat: places.lat, lng: places.lng })
		.from(itineraryStops)
		.innerJoin(places, eq(places.id, itineraryStops.placeId))
		.where(eq(itineraryStops.day, date))
		.orderBy(asc(itineraryStops.position));
	const legs = [];
	for (let i = 1; i < rows.length; i++) {
		const a = rows[i - 1], b = rows[i];
		if (a.lat === b.lat && a.lng === b.lng) continue;
		// the transport of a stop is how you get there
		const leg = await routeLeg([a.lng, a.lat], [b.lng, b.lat], b.transport === 'pe');
		legs.push({ transport: b.transport, ...leg });
	}
	return { legs };
}
