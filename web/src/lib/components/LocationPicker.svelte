<script lang="ts">
	import type { Map as MLMap, Marker } from 'maplibre-gl';
	import MapView from './MapView.svelte';
	import Icon from './Icon.svelte';
	import { pinElement, replayDrop } from '$lib/map-markers';

	let {
		lat = $bindable(),
		lng = $bindable(),
		editable = false,
		color = '#23824F',
		height = 260,
		onchoose
	}: {
		lat: number | null;
		lng: number | null;
		editable?: boolean;
		color?: string;
		height?: number;
		/** a place picked from the search (to fill in its name and address) */
		onchoose?: (r: { name: string; detail: string; lat: number; lng: number }) => void;
	} = $props();

	type Result = { name: string; detail: string; lat: number; lng: number };

	let marker: Marker | null = null;
	let map: MLMap | null = null;
	let place: ((p: { lng: number; lat: number }, animate?: boolean) => void) | null = null;
	const start = lat != null && lng != null ? ([lng, lat] as [number, number]) : undefined;

	function ready(m: MLMap, ml: typeof import('maplibre-gl')) {
		map = m;
		place = (lngLat, animate = true) => {
			if (!marker) {
				const el = pinElement(color);
				marker = new ml.Marker({ element: el, anchor: 'bottom', draggable: editable }).setLngLat(lngLat).addTo(m);
				if (editable) {
					marker.on('dragend', () => {
						const p = marker!.getLngLat();
						lat = p.lat;
						lng = p.lng;
						replayDrop(el);
					});
				}
			} else marker.setLngLat(lngLat);
			if (animate) replayDrop(marker.getElement());
			lat = lngLat.lat;
			lng = lngLat.lng;
		};
		if (start) place({ lng: start[0], lat: start[1] });
		if (editable) {
			m.on('click', (e) => {
				place!(e.lngLat);
				m.easeTo({ center: e.lngLat, duration: 500 });
			});
			m.getCanvas().style.cursor = 'crosshair';
		}
	}

	// ---- place search ----
	let query = $state('');
	let results = $state<Result[]>([]);
	let searching = $state(false);
	let searchError = $state('');
	let chosen = $state('');
	let timer: ReturnType<typeof setTimeout> | undefined;
	let seq = 0;

	function onInput() {
		clearTimeout(timer);
		searchError = '';
		chosen = '';
		const q = query.trim();
		if (q.length < 2) {
			results = [];
			return;
		}
		timer = setTimeout(() => search(q), 350);
	}

	async function search(q: string) {
		const mine = ++seq;
		searching = true;
		const c = map?.getCenter();
		const params = new URLSearchParams({ q });
		if (c) {
			params.set('lat', c.lat.toFixed(4));
			params.set('lng', c.lng.toFixed(4));
		}
		try {
			const r = await fetch(`/api/places?${params}`);
			const body = await r.json();
			if (mine !== seq) return;
			if (!r.ok) throw new Error(body.message);
			results = body;
			if (!results.length) searchError = 'Nenhum lugar encontrado.';
		} catch (e) {
			if (mine === seq) searchError = (e as Error).message || 'Não foi possível buscar.';
		} finally {
			if (mine === seq) searching = false;
		}
	}

	function choose(r: Result) {
		place?.({ lat: r.lat, lng: r.lng });
		map?.flyTo({ center: [r.lng, r.lat], zoom: 16, duration: 900 });
		chosen = r.name;
		onchoose?.(r);
		query = '';
		results = [];
	}
</script>

{#if editable}
	<div class="search">
		<label class="field">
			<Icon name="search" size={18} />
			<span class="sr-only">Buscar lugar</span>
			<input type="search" bind:value={query} oninput={onInput} placeholder="Buscar lugar (ex.: Jardim Botânico)" autocomplete="off" enterkeyhint="search" />
			{#if searching}<span class="spin" aria-hidden="true"></span>{/if}
		</label>
		{#if results.length}
			<ul class="results card" aria-label="Lugares encontrados">
				{#each results as r, i (i)}
					<li>
						<button type="button" onclick={() => choose(r)}>
							<Icon name="pin" size={16} />
							<span><strong>{r.name}</strong>{#if r.detail}<small>{r.detail}</small>{/if}</span>
						</button>
					</li>
				{/each}
			</ul>
		{:else if searchError}
			<p class="small muted">{searchError}</p>
		{:else if chosen}
			<p class="small ok" role="status"><Icon name="check" size={15} /> {chosen}. Arraste o marcador para ajustar.</p>
		{/if}
	</div>
{/if}

<div class="picker" style:height="{height}px"><MapView center={start} zoom={start ? 15 : 12} framed onready={ready} /></div>

<style>
	.search { display: grid; gap: 6px; margin-bottom: 10px; }
	.field {
		display: flex; align-items: center; gap: 8px; padding: 0 12px; min-height: 46px;
		background: var(--surface); border: 2.5px solid var(--line); border-radius: 14px; color: var(--muted);
	}
	.field:focus-within { border-color: var(--sea); }
	.field input { flex: 1; min-width: 0; border: 0; background: none; padding: 10px 0; color: var(--ink); font: inherit; box-shadow: none; outline: none; }
	.spin { width: 16px; height: 16px; border-radius: 50%; border: 2.5px solid var(--line); border-top-color: var(--sea); animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }
	.results { list-style: none; margin: 0; padding: 4px; max-height: 260px; overflow-y: auto; }
	.results button {
		display: flex; align-items: flex-start; gap: 8px; width: 100%; min-height: 44px; padding: 8px 10px; text-align: left;
		background: none; border: 0; border-radius: 10px; color: var(--ink); font: inherit; cursor: pointer;
	}
	.results button:hover, .results button:focus-visible { background: var(--surface-2); }
	.results button :global(svg) { flex: none; margin-top: 3px; color: var(--coral); }
	.results span { display: grid; min-width: 0; }
	.results small { color: var(--muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.search p { margin: 0; }
	.ok { display: flex; align-items: center; gap: 4px; color: var(--leaf); font-weight: 700; }
</style>
