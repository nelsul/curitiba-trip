import { browser } from '$app/environment';

export type Pos = { lat: number; lng: number; accuracy: number; at: number };

export const loc = $state({
	sharing: false,
	pos: null as Pos | null,
	error: ''
});

const PREF = 'compartilhar-localizacao';
let watchId: number | null = null;
let lastSent: Pos | null = null;

function distanceM(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
	const R = 6371e3, rad = Math.PI / 180;
	const dLat = (b.lat - a.lat) * rad, dLng = (b.lng - a.lng) * rad;
	const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLng / 2) ** 2;
	return 2 * R * Math.asin(Math.sqrt(h));
}

function fromGeo(p: GeolocationPosition): Pos {
	return { lat: p.coords.latitude, lng: p.coords.longitude, accuracy: p.coords.accuracy, at: p.timestamp };
}

function geoError(e: GeolocationPositionError) {
	return e.code === e.PERMISSION_DENIED
		? 'Sem permissão de localização. Libere nas configurações do navegador.'
		: 'Não foi possível obter sua localização.';
}

async function send(p: Pos, force = false) {
	if (!force && lastSent && distanceM(lastSent, p) < 30 && p.at - lastSent.at < 3 * 60_000) return;
	if (p.accuracy > 500) return; // too imprecise to be useful
	lastSent = p;
	try {
		await fetch('/api/locations', {
			method: 'POST',
			headers: { 'content-type': 'application/json' },
			body: JSON.stringify({ lat: p.lat, lng: p.lng, accuracy: p.accuracy })
		});
	} catch {
		lastSent = null; // retry on next update
	}
}

export function startSharing() {
	if (!browser || !('geolocation' in navigator)) {
		loc.error = 'Este navegador não informa localização.';
		return;
	}
	if (watchId !== null) return;
	loc.sharing = true;
	loc.error = '';
	try { localStorage.setItem(PREF, '1'); } catch {}
	watchId = navigator.geolocation.watchPosition(
		(p) => {
			loc.pos = fromGeo(p);
			loc.error = '';
			send(loc.pos);
		},
		(e) => {
			loc.error = geoError(e);
			if (e.code === e.PERMISSION_DENIED) stopSharing();
		},
		{ enableHighAccuracy: true, maximumAge: 15_000, timeout: 30_000 }
	);
}

export function stopSharing() {
	if (watchId !== null) navigator.geolocation.clearWatch(watchId);
	watchId = null;
	loc.sharing = false;
	try { localStorage.setItem(PREF, '0'); } catch {}
}

export function restoreSharing() {
	let pref: string | null = null;
	try { pref = localStorage.getItem(PREF); } catch {}
	if (pref === '1') startSharing();
	document.addEventListener('visibilitychange', () => {
		if (document.visibilityState === 'visible' && loc.sharing && loc.pos) send(loc.pos, true);
	});
}

/** One-shot position (reuses a recent fix). */
export function currentPosition(maxAgeMs = 120_000): Promise<Pos> {
	if (loc.pos && Date.now() - loc.pos.at < maxAgeMs) return Promise.resolve(loc.pos);
	return new Promise((resolve, reject) => {
		if (!('geolocation' in navigator)) return reject(new Error('Este navegador não informa localização.'));
		navigator.geolocation.getCurrentPosition(
			(p) => {
				loc.pos = fromGeo(p);
				resolve(loc.pos);
			},
			(e) => reject(new Error(geoError(e))),
			{ enableHighAccuracy: true, maximumAge: maxAgeMs, timeout: 20_000 }
		);
	});
}
