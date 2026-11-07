<script lang="ts" module>
	export const ICONS = {
		journal: 'M6 3h10l3 3v15H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM8 9h8M8 13h8M8 17h5',
		map: 'M9 4 3 6v14l6-2 6 2 6-2V4l-6 2-6-2zm0 0v14m6-12v14',
		upload: 'M12 19V7m0 0-5 5m5-5 5 5M5 4h14',
		ticket: 'M3 9a2 2 0 0 0 0 4v5h18v-5a2 2 0 0 0 0-4V5H3zM14 5v2m0 3v2m0 3v3',
		user: 'M12 4a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM4 21c1.5-4 4.5-6 8-6s6.5 2 8 6',
		calendar: 'M7 3v4m10-4v4M4 9h16M5 5h14a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z',
		people: 'M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2 20c1-3.5 3.6-5.5 7-5.5s6 2 7 5.5M16 4.5a3.5 3.5 0 0 1 0 6.5M18 14.8c1.9.8 3.3 2.6 4 5.2',
		pin: 'M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21zM12 12a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
		camera: 'M4 8h3l2-3h6l2 3h3v11H4zM12 17a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z',
		plane: 'M21 15.5 13.5 11V5.5a1.5 1.5 0 0 0-3 0V11L3 15.5v2l7.5-2.3V19L8 20.7V22l4-1 4 1v-1.3L13.5 19v-3.8l7.5 2.3z',
		car: 'M5 11l1.8-4.5A2 2 0 0 1 8.7 5h6.6a2 2 0 0 1 1.9 1.5L19 11M4 11h16v6H4zM6.5 17v2M17.5 17v2M7 14h.01M17 14h.01',
		island: 'M3 19c3-2 6-2 9 0s6 2 9 0M12 17V8m0 0c-2-3-5-3-7-2 2 0 4 1 7 2zm0 0c1-3 4-4 7-3-2 .5-4 1.5-7 3zm0 0c-1.5-2-1.5-4 0-5 0 1.5.5 3 0 5z',
		chat: 'M4 5h16v11H9l-5 4z',
		check: 'M5 12.5l4.5 4.5L19 7.5',
		heart: 'M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z',
		download: 'M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 20h14',
		play: 'M8 5v14l11-7z',
		leaf: 'M5 19C5 10 11 4 20 4c0 9-6 15-15 15zm0 0 8-8',
		expand: 'M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5'
	} as const;
	export type IconName = keyof typeof ICONS;
</script>

<script lang="ts">
	let { name, size = 22, stroke = 2.3, label }: { name: IconName; size?: number; stroke?: number; label?: string } = $props();
</script>

<svg
	viewBox="0 0 24 24"
	width={size}
	height={size}
	fill="none"
	stroke="currentColor"
	stroke-width={stroke}
	stroke-linecap="round"
	stroke-linejoin="round"
	role={label ? 'img' : undefined}
	aria-label={label}
	aria-hidden={label ? undefined : 'true'}
><path d={ICONS[name]} /></svg>
