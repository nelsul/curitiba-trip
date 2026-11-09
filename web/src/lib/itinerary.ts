// Roteiro types and links shared by the server and the browser. The data itself lives in the database
// (places, itinerary_days, itinerary_stops) and everyone can edit it on /roteiro.

export type Transport = 'onibus' | 'turismo' | 'uber' | 'pe' | 'rodo';
export type PlaceCategory = 'comer' | 'passeio' | 'outro';

export const TRANSPORT: Record<Transport, { label: string; color: string }> = {
	onibus: { label: '🚌 Ônibus', color: 'var(--bus)' },
	turismo: { label: '🚍 Linha Turismo', color: 'var(--leaf)' },
	uber: { label: '🚗 Uber', color: 'var(--plum)' },
	pe: { label: '🚶 A pé', color: 'var(--coral)' },
	rodo: { label: '🚌 Ônibus Graciosa', color: 'var(--bus)' }
};

export const CATEGORY: Record<PlaceCategory, { label: string; plural: string; color: string }> = {
	comer: { label: 'Comer', plural: 'Para comer', color: 'var(--coral)' },
	passeio: { label: 'Passear', plural: 'Para passear', color: 'var(--leaf)' },
	outro: { label: 'Outro', plural: 'Outros', color: 'var(--sea)' }
};

export type PlacePhoto = { id: string; url: string };

export type RoteiroPlace = {
	id: string;
	name: string;
	category: PlaceCategory;
	lat: number;
	lng: number;
	address: string;
	hours: string;
	price: string;
	/** 0 = grátis, 1–4 = $…$$$$, null = não sei */
	priceLevel: number | null;
	description: string;
	link: string;
	googlePlaceId: string | null;
	photos: PlacePhoto[];
};

export type RoteiroStop = {
	id: string;
	time: string;
	placeId: string | null;
	label: string;
	transport: Transport;
	note: string;
	/** ISO time someone ticked "Fomos!" (null = not yet) and who */
	visitedAt: string | null;
	visitedBy: string | null;
};
export type RoteiroDay = {
	date: string;
	title: string;
	who: string;
	lead: string;
	wedding: boolean;
	stops: RoteiroStop[];
	/** the stay (hotel/Airbnb) the person reading leaves from that morning / goes back to that night, if any */
	startStay: string | null;
	endStay: string | null;
};

export type StayKind = 'hotel' | 'airbnb' | 'casa';

export const STAY_KIND: Record<StayKind, { label: string; emoji: string }> = {
	hotel: { label: 'Hotel', emoji: '🏨' },
	airbnb: { label: 'Airbnb', emoji: '🏠' },
	casa: { label: 'Casa', emoji: '🏡' }
};

/** Where people sleep, set up by admins. `checkIn` = first night, `checkOut` = the day they leave (null = whole trip). */
export type RoteiroStay = {
	id: string;
	name: string;
	kind: StayKind;
	lat: number;
	lng: number;
	address: string;
	link: string;
	checkIn: string | null;
	checkOut: string | null;
	note: string;
	/** user ids staying there */
	guests: string[];
};

/** The stays `userId` has on `date`, from the check-in day to the check-out day (both included). */
const staysOn = (stays: RoteiroStay[], userId: string, date: string) =>
	stays.filter((s) => s.guests.includes(userId) && (!s.checkIn || s.checkIn <= date) && (!s.checkOut || date <= s.checkOut));

/**
 * Where `userId` leaves from on `date`: every day of the stay counts, the arrival day too (the Roteiro is about the
 * outings, not the trip there). On a day they change places, it's the one they slept in.
 */
export function morningStay(stays: RoteiroStay[], userId: string, date: string) {
	const on = staysOn(stays, userId, date);
	return on.find((s) => !s.checkIn || s.checkIn < date) ?? on[0] ?? null;
}

/** Where `userId` goes back to at the end of `date` (on a day they change places, the new one). */
export function nightStay(stays: RoteiroStay[], userId: string, date: string) {
	const on = staysOn(stays, userId, date);
	return on.find((s) => !s.checkOut || date < s.checkOut) ?? on[0] ?? null;
}

type LatLng = { lat: number; lng: number; name?: string; googlePlaceId?: string | null };

/** Google Maps page for the place (its Google listing when we know it, otherwise the coordinates). */
export function placeUrl(p: LatLng) {
	const params = new URLSearchParams({ api: '1', query: p.googlePlaceId && p.name ? p.name : `${p.lat},${p.lng}` });
	if (p.googlePlaceId) params.set('query_place_id', p.googlePlaceId);
	return `https://www.google.com/maps/search/?${params}`;
}

/** Google Maps directions through the day's places, in order. */
export function routeUrl(pts: LatLng[]): string | null {
	if (pts.length < 2) return null;
	const ll = (p: LatLng) => `${p.lat},${p.lng}`;
	const params = new URLSearchParams({ api: '1', origin: ll(pts[0]), destination: ll(pts.at(-1)!), travelmode: 'driving' });
	if (pts.length > 2) params.set('waypoints', pts.slice(1, -1).map(ll).join('|'));
	return `https://www.google.com/maps/dir/?${params}`;
}

/** Opens the Uber app (or m.uber.com) with pickup = current location and this place as the destination. */
export function uberUrl(p: { lat: number; lng: number; name: string }) {
	// encodeURIComponent (not URLSearchParams) so spaces become %20, not "+", in the place name
	const q = Object.entries({
		action: 'setPickup',
		pickup: 'my_location',
		'dropoff[latitude]': String(p.lat),
		'dropoff[longitude]': String(p.lng),
		'dropoff[nickname]': p.name
	})
		.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
		.join('&');
	return `https://m.uber.com/ul/?${q}`;
}

/** "$$" for price levels 1–4, "Grátis" for 0. */
export const priceSigns = (level: number | null) => (level == null ? '' : level === 0 ? 'Grátis' : '$'.repeat(level));

/** "9h35" / "14h" → "09:35" / "14:00" for <input type="time">; anything else → "" */
export function timeToInput(t: string) {
	const m = /^(\d{1,2})h(\d{2})?$/.exec(t.trim());
	return m ? `${m[1].padStart(2, '0')}:${m[2] ?? '00'}` : '';
}

/** "09:35" → "9h35", "14:00" → "14h" (the format the apps read for reminders) */
export function inputToTime(v: string) {
	const m = /^(\d{2}):(\d{2})$/.exec(v);
	if (!m) return '';
	const h = String(Number(m[1]));
	return m[2] === '00' ? `${h}h` : `${h}h${m[2]}`;
}
