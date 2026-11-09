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
		expand: 'M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5',
		gallery: 'M6 3h12a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3zM3 8h18M8 3l3 5M14 3l3 5M10 11.5v6l5-3z',
		search: 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20 20l-4-4',
		locate: 'M12 18a6 6 0 1 0 0-12 6 6 0 0 0 0 12zM12 2v4M12 18v4M2 12h4M18 12h4M12 13.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z',
		sound: 'M4 9h4l5-4v14l-5-4H4zM16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12',
		mute: 'M4 9h4l5-4v14l-5-4H4zM16 9.5l5 5M21 9.5l-5 5',
		home: 'M3 11 12 4l9 7M5.5 9.5V20h13V9.5M10 20v-5.5h4V20',
		wallet: 'M4 7h15a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1zM4 7l11-3v3M16 13.5h.01',
		grid: 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z',
		sun: 'M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4',
		partly: 'M8 3v1.5M3.8 4.8l1 1M2 9h1.5M11.2 5.8l1-1M5.2 11.5A3.5 3.5 0 1 1 11.4 8M8.5 20h9a3.5 3.5 0 1 0-1-6.9 5 5 0 0 0-9.3 1.4A2.75 2.75 0 0 0 8.5 20z',
		cloud: 'M7 19h10.5a4 4 0 1 0-1.2-7.8A6 6 0 0 0 4.6 13 3 3 0 0 0 7 19z',
		fog: 'M7 13h10.5a3.5 3.5 0 1 0-1.2-6.8A5.5 5.5 0 0 0 5.5 8.5 2.5 2.5 0 0 0 7 13zM4 17h16M6 21h12',
		rain: 'M7 14h10.5a3.5 3.5 0 1 0-1.2-6.8A5.5 5.5 0 0 0 5.5 9.5 2.5 2.5 0 0 0 7 14zM8 17l-1 3M12 17l-1 3M16 17l-1 3',
		storm: 'M7 14h10.5a3.5 3.5 0 1 0-1.2-6.8A5.5 5.5 0 0 0 5.5 9.5 2.5 2.5 0 0 0 7 14zM12.5 15 10 18.5h4L11.5 22',
		share: 'M12 15V3m0 0L8 7m4-4 4 4M7 10H5v11h14V10h-2',
		trash: 'M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3',
		close: 'M6 6l12 12M18 6 6 18',
		sparkle: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 16l.8 2.2L22 19l-2.2.8L19 22l-.8-2.2L16 19l2.2-.8z',
		copy: 'M9 9h11v11H9zM5 15H4V4h11v1',
		bell: 'M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20.5a2 2 0 0 0 4 0',
		video: 'M3 7h12v10H3zM15 10.5l6-3.5v10l-6-3.5',
		up: 'M12 19V5m0 0-6 6m6-6 6 6',
		down: 'M12 5v14m0 0-6-6m6 6 6-6',
		plus: 'M12 5v14M5 12h14',
		clock: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2',
		ring: 'M12 21a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13zM9 4.5 10.5 2h3L15 4.5 12 8z',
		external: 'M10 14 20 4m0 0h-6m6 0v6M19 13v7H4V5h7',
		frame: 'M3 3h18v18H3zM6.5 6.5h11v8h-11zM6.5 18h6'
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
