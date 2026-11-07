import { json } from '@sveltejs/kit';
import { DAYS, PLACES, TRANSPORT, placeUrl, routeUrl, uberUrl } from '$lib/itinerary';
import type { RequestHandler } from './$types';

/** The day-by-day itinerary, with places resolved and the Google Maps / Uber links ready to open. */
export const GET: RequestHandler = () =>
	json({
		transport: Object.fromEntries(Object.entries(TRANSPORT).map(([k, v]) => [k, { label: v.label }])),
		days: DAYS.map((d) => ({
			...d,
			wedding: !!d.wedding,
			routeUrl: routeUrl(d),
			stops: d.stops.map((s) => {
				const p = s.place ? PLACES[s.place] : null;
				return {
					time: s.time,
					transport: s.transport,
					note: s.note,
					title: p?.name ?? s.label ?? '',
					place: p ? { ...p, id: s.place, mapsUrl: placeUrl(p), uberUrl: uberUrl(p) } : null
				};
			})
		}))
	});
