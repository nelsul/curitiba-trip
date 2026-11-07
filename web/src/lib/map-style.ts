import type { StyleSpecification, LayerSpecification } from 'maplibre-gl';

const BASE = 'https://tiles.openfreemap.org/styles/liberty';

type Palette = {
	land: string; residential: string; park: string; wood: string; sand: string; water: string; waterLine: string;
	building: string; buildingLine: string; road: string; roadMajor: string; roadCasing: string; roadMajorCasing: string;
	path: string; rail: string; text: string; halo: string; waterText: string; aeroway: string;
};

const DAY: Palette = {
	land: '#d6ecaa', residential: '#e1f0bb', park: '#b6e08d', wood: '#9fd27c', sand: '#f6e6ad',
	water: '#86d4e2', waterLine: '#6cc4d6', building: '#f6dfba', buildingLine: '#e2c393',
	road: '#fffcf0', roadMajor: '#ffeaa6', roadCasing: '#e6d4a6', roadMajorCasing: '#e3b95c',
	path: '#c9a878', rail: '#b49572', text: '#5a4530', halo: '#fffcf0', waterText: '#1f6f80', aeroway: '#ece3c6'
};

const NIGHT: Palette = {
	land: '#22324f', residential: '#273958', park: '#21494a', wood: '#1d4344', sand: '#3a4560',
	water: '#13223d', waterLine: '#1b3155', building: '#2f416a', buildingLine: '#3b4f7c',
	road: '#3b4f78', roadMajor: '#5b6a92', roadCasing: '#1b2741', roadMajorCasing: '#1b2741',
	path: '#4f6390', rail: '#56688f', text: '#f4eed6', halo: '#1b2741', waterText: '#8fc9dc', aeroway: '#2d3b5c'
};

const paint = (l: LayerSpecification, key: string, value: unknown) => {
	(l as { paint?: Record<string, unknown> }).paint = { ...((l as { paint?: Record<string, unknown> }).paint ?? {}), [key]: value };
};
/** Fill + matching outline (the base style draws light outlines that glow at night). */
const fill = (l: LayerSpecification, color: string, opacity?: number) => {
	paint(l, 'fill-color', color);
	paint(l, 'fill-outline-color', color);
	if (opacity !== undefined) paint(l, 'fill-opacity', opacity);
};
const hide = (l: LayerSpecification) => {
	(l as { layout?: Record<string, unknown> }).layout = { ...((l as { layout?: Record<string, unknown> }).layout ?? {}), visibility: 'none' };
};

let cache: Promise<StyleSpecification> | null = null;

/** OpenFreeMap "liberty", recolored as a soft, toy-like island map. */
export async function islandStyle(night: boolean): Promise<StyleSpecification> {
	cache ??= fetch(BASE).then((r) => r.json());
	const style: StyleSpecification = structuredClone(await cache);
	const c = night ? NIGHT : DAY;

	for (const l of style.layers) {
		const id = l.id;
		const src = 'source-layer' in l ? l['source-layer'] : undefined;
		if (l.type === 'background') paint(l, 'background-color', c.land);
		else if (id === 'natural_earth' || l.type === 'fill-extrusion' || id === 'road_area_pattern') hide(l);
		else if (l.type === 'fill') {
			if (src === 'water') { paint(l, 'fill-color', c.water); paint(l, 'fill-outline-color', c.waterLine); }
			else if (id === 'landcover_wood') fill(l, c.wood, 1);
			else if (id === 'park' || id.startsWith('landcover_grass') || id === 'landuse_pitch' || id === 'landuse_cemetery') fill(l, c.park, 1);
			else if (id === 'landcover_sand') fill(l, c.sand);
			else if (id === 'landuse_residential') fill(l, c.residential, 1);
			else if (id === 'building') { paint(l, 'fill-color', c.building); paint(l, 'fill-outline-color', c.buildingLine); paint(l, 'fill-opacity', 1); }
			else if (src === 'aeroway') fill(l, c.aeroway);
			else if (src === 'landuse' || src === 'landcover') fill(l, c.residential, 0.8);
		} else if (l.type === 'line') {
			if (src === 'waterway') paint(l, 'line-color', c.water);
			else if (id === 'park_outline') hide(l);
			else if (src === 'boundary') paint(l, 'line-color', c.path);
			else if (src === 'aeroway') paint(l, 'line-color', c.aeroway);
			else if (src === 'transportation') {
				const major = /motorway|trunk|primary|secondary|tertiary/.test(id);
				if (/rail/.test(id)) paint(l, 'line-color', c.rail);
				else if (/path|pedestrian/.test(id)) { paint(l, 'line-color', c.path); }
				else if (id.endsWith('_casing')) paint(l, 'line-color', major ? c.roadMajorCasing : c.roadCasing);
				else paint(l, 'line-color', major ? c.roadMajor : c.road);
			}
		} else if (l.type === 'symbol') {
			if (id === 'poi_r20' || id === 'poi_r7' || id.startsWith('highway-shield') || id === 'road_shield_us' || id.startsWith('road_one_way')) {
				hide(l);
				continue;
			}
			const water = src === 'water_name' || src === 'waterway';
			paint(l, 'text-color', water ? c.waterText : c.text);
			paint(l, 'text-halo-color', c.halo);
			paint(l, 'text-halo-width', 2);
			paint(l, 'text-halo-blur', 0.5);
		}
	}
	return style;
}
