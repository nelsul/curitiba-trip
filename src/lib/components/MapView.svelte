<script lang="ts">
	import { onMount } from 'svelte';
	import type { Map as MLMap } from 'maplibre-gl';

	type ML = typeof import('maplibre-gl');
	let {
		center = [-49.2733, -25.4284] as [number, number],
		zoom = 12,
		framed = false,
		onready
	}: { center?: [number, number]; zoom?: number; framed?: boolean; onready?: (map: MLMap, ml: ML) => void } = $props();

	let el: HTMLDivElement;
	let failed = $state(false);
	let loading = $state(true);

	onMount(() => {
		let map: MLMap | undefined;
		(async () => {
			try {
				const night = matchMedia('(prefers-color-scheme: dark)').matches;
				const [ml, , { islandStyle }] = await Promise.all([
					import('maplibre-gl'),
					import('maplibre-gl/dist/maplibre-gl.css'),
					import('$lib/map-style')
				]);
				map = new ml.Map({
					container: el,
					style: await islandStyle(night),
					center,
					zoom,
					attributionControl: { compact: true },
					pitchWithRotate: false
				});
				map.addControl(new ml.NavigationControl({ showCompass: false }), 'top-right');
				map.on('load', () => {
					loading = false;
					onready?.(map!, ml);
				});
			} catch (e) {
				console.error(e);
				failed = true;
			}
		})();
		return () => map?.remove();
	});
</script>

<div class="map" class:framed bind:this={el}>
	{#if loading && !failed}<div class="loading" aria-live="polite"><span class="boat">⛵</span> Carregando o mapa…</div>{/if}
	{#if failed}<p class="fail">Não foi possível carregar o mapa.</p>{/if}
</div>

<style>
	.map { position: relative; width: 100%; height: 100%; background: var(--sea-light); }
	.framed { border: 4px solid var(--surface); border-radius: var(--radius); box-shadow: 0 0 0 2.5px var(--line), 0 5px 0 2.5px var(--shadow); overflow: hidden; }
	.loading { position: absolute; inset: 0; z-index: 2; display: grid; place-content: center; gap: 6px; text-align: center; font-weight: 800; color: var(--ink); }
	.boat { font-size: 2rem; animation: bob 1.4s ease-in-out infinite; }
	.fail { padding: 16px; }
	.map :global(.maplibregl-ctrl-group) { border-radius: 14px; overflow: hidden; border: 2.5px solid var(--line); box-shadow: 0 3px 0 var(--shadow); background: var(--surface); }
	.map :global(.maplibregl-ctrl-group button) { width: 38px; height: 38px; }
	.map :global(.maplibregl-ctrl-group button + button) { border-top: 2px solid var(--line); }
	.map :global(.maplibregl-ctrl-attrib) { border-radius: 10px; font-size: 10px; }
</style>
