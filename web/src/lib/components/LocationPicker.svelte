<script lang="ts">
	import type { Map as MLMap, Marker } from 'maplibre-gl';
	import MapView from './MapView.svelte';
	import { pinElement, replayDrop } from '$lib/map-markers';

	let {
		lat = $bindable(),
		lng = $bindable(),
		editable = false,
		color = '#23824F'
	}: { lat: number | null; lng: number | null; editable?: boolean; color?: string } = $props();

	let marker: Marker | null = null;
	const start = lat != null && lng != null ? ([lng, lat] as [number, number]) : undefined;

	function ready(map: MLMap, ml: typeof import('maplibre-gl')) {
		const place = (lngLat: { lng: number; lat: number }, animate = true) => {
			if (!marker) {
				const el = pinElement(color);
				marker = new ml.Marker({ element: el, anchor: 'bottom', draggable: editable }).setLngLat(lngLat).addTo(map);
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
			map.on('click', (e) => {
				place(e.lngLat);
				map.easeTo({ center: e.lngLat, duration: 500 });
			});
			map.getCanvas().style.cursor = 'crosshair';
		}
	}
</script>

<div class="picker"><MapView center={start} zoom={start ? 15 : 12} framed onready={ready} /></div>

<style>
	.picker { height: 260px; }
</style>
