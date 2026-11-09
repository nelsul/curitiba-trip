<script lang="ts">
	import type { Map as MLMap, GeoJSONSource } from 'maplibre-gl';
	import MapView from '$lib/components/MapView.svelte';
	import { TRANSPORT, type Transport } from '$lib/itinerary';

	type Point = { n: number; name: string; lat: number; lng: number; transport: Transport; photo?: string | null; visited?: boolean };
	let {
		date,
		points,
		onpick,
		active = null,
		height = '280px'
	}: { date: string; points: Point[]; onpick?: (n: number) => void; active?: number | null; height?: string } = $props();

	const pins = new Map<number, HTMLElement>();
	$effect(() => {
		const a = active; // read first, so the effect follows it even before the pins exist
		for (const [n, el] of pins) el.classList.toggle('on', n === a);
	});

	let note = $state('');
	// svelte-ignore state_referenced_locally
	const first = points[0];

	/** CSS var → color the map can use */
	function cssColor(v: string) {
		const name = v.match(/var\((--[\w-]+)\)/)?.[1];
		return name ? getComputedStyle(document.documentElement).getPropertyValue(name).trim() || '#5fc4c4' : v;
	}

	async function ready(map: MLMap, ml: typeof import('maplibre-gl')) {
		map.addSource('route', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } });
		map.addLayer({
			id: 'route-casing', type: 'line', source: 'route',
			layout: { 'line-cap': 'round', 'line-join': 'round' },
			paint: { 'line-color': '#fffcf0', 'line-width': 8, 'line-opacity': 0.85 }
		});
		map.addLayer({
			id: 'route', type: 'line', source: 'route',
			layout: { 'line-cap': 'round', 'line-join': 'round' },
			paint: {
				'line-color': ['get', 'color'],
				'line-width': 4.5,
				// straight lines (no street route found) and walking legs are dashed
				'line-dasharray': ['case', ['get', 'dashed'], ['literal', [1, 1.6]], ['literal', [1, 0]]]
			}
		});

		const bounds = new ml.LngLatBounds();
		for (const p of points) {
			const el = document.createElement('button');
			el.type = 'button';
			el.className = 'route-stop';
			// MapLibre moves the marker with `transform`, so the look (and its zoom on hover) lives on an inner span
			const dot = document.createElement('span');
			if (p.photo) {
				// the place's picture in a round frame, with its number on a little badge
				dot.className = 'photo';
				const img = document.createElement('img');
				img.src = p.photo;
				img.alt = '';
				const num = document.createElement('b');
				num.textContent = String(p.n);
				dot.append(img, num);
			} else dot.textContent = String(p.n);
			if (p.visited) {
				el.classList.add('visited');
				const ok = document.createElement('i');
				ok.textContent = '✓';
				ok.setAttribute('aria-hidden', 'true');
				dot.append(ok);
			}
			el.append(dot);
			if (p.visited) el.setAttribute('aria-label', `${p.n}. ${p.name} (já fomos)`);
			el.setAttribute('aria-label', `${p.n}. ${p.name}`);
			el.onclick = () => onpick?.(p.n);
			pins.set(p.n, el);
			new ml.Marker({ element: el }).setLngLat([p.lng, p.lat]).addTo(map);
			bounds.extend([p.lng, p.lat]);
		}
		const fit = () => {
			if (points.length > 1) map.fitBounds(bounds, { padding: { top: 40, left: 40, right: 60, bottom: 56 }, maxZoom: 15, duration: 0 });
		};
		fit();
		// the column changes width (editing a day, resizing the window): show the whole day again
		map.on('resize', fit);

		if (points.length < 2) return;
		try {
			const r = await fetch(`/api/roteiro/days/${date}/route`);
			if (!r.ok) throw new Error();
			const { legs } = (await r.json()) as { legs: { transport: Transport; coordinates: [number, number][]; routed: boolean }[] };
			(map.getSource('route') as GeoJSONSource | undefined)?.setData({
				type: 'FeatureCollection',
				features: legs.map((l) => ({
					type: 'Feature',
					properties: { color: cssColor(TRANSPORT[l.transport].color), dashed: !l.routed || l.transport === 'pe' },
					geometry: { type: 'LineString', coordinates: l.coordinates }
				}))
			});
			if (legs.some((l) => !l.routed)) note = 'Alguns trechos aparecem em linha reta (sem rota pelas ruas).';
		} catch {
			note = 'Não foi possível traçar a rota agora.';
		}
	}
</script>

<div class="route-map" style:height>
	<MapView center={first ? [first.lng, first.lat] : undefined} zoom={14} framed onready={ready} />
</div>
{#if note}<p class="small muted note">{note}</p>{/if}

<style>
	.route-map { margin: 4px 0 6px; min-height: 260px; }
	.note { margin: 0 0 8px; }
	.route-map :global(.route-stop) { padding: 0; border: 0; background: none; cursor: pointer; }
	.route-map :global(.route-stop span) {
		display: grid; place-items: center; width: 30px; height: 30px; border-radius: 50%; cursor: pointer; padding: 0;
		background: var(--sun); color: #4a3410; border: 3px solid #fffcf0; font: 700 0.9rem var(--font-display);
		box-shadow: 0 3px 0 rgb(0 0 0 / 0.3); transition: transform 0.15s var(--bounce);
	}
	.route-map :global(.route-stop span) { position: relative; }
	.route-map :global(.route-stop span.photo) { width: 46px; height: 46px; padding: 0; overflow: visible; background: #fffcf0; }
	.route-map :global(.route-stop span.photo img) { width: 100%; height: 100%; border-radius: 50%; object-fit: cover; }
	.route-map :global(.route-stop span.photo b) {
		position: absolute; left: -6px; top: -6px; display: grid; place-items: center; width: 20px; height: 20px; border-radius: 50%;
		background: var(--sun); color: #4a3410; font-size: 0.72rem; border: 2px solid #fffcf0;
	}
	.route-map :global(.route-stop i) {
		position: absolute; right: -6px; bottom: -6px; display: grid; place-items: center; width: 18px; height: 18px; border-radius: 50%;
		background: var(--leaf); color: var(--on-leaf); font: 800 0.7rem/1 var(--font-body, sans-serif); font-style: normal; border: 2px solid #fffcf0;
	}
	.route-map :global(.route-stop.visited span:not(.photo)) { background: var(--leaf); color: var(--on-leaf); }
	.route-map :global(.route-stop.on) { z-index: 2; }
	.route-map :global(.route-stop.on span) { transform: scale(1.35); background: var(--coral); color: #fff; }
</style>
