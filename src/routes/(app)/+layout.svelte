<script lang="ts">
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import { restoreSharing, loc } from '$lib/location.svelte';
	let { children } = $props();

	const items = [
		{ href: '/', label: 'Linha do tempo', short: 'Diário', color: 'var(--leaf)', icon: 'M6 4h9l3 3v13H6zM9 10h6M9 14h6M9 18h3' },
		{ href: '/mapa', label: 'Mapa', short: 'Mapa', color: 'var(--sea)', icon: 'M9 4 3 6v14l6-2 6 2 6-2V4l-6 2-6-2zm0 0v14m6-12v14' },
		{ href: '/enviar', label: 'Enviar', short: 'Enviar', color: 'var(--sun)', icon: 'M12 19V7m0 0-5 5m5-5 5 5M5 4h14', primary: true },
		{ href: '/roteiro', label: 'Roteiro', short: 'Roteiro', color: 'var(--coral)', icon: 'M3 9a2 2 0 0 0 0 4v5h18v-5a2 2 0 0 0 0-4V5H3zM14 5v2m0 3v2m0 3v3' },
		{ href: '/mais', label: 'Mais', short: 'Mais', color: 'var(--plum)', icon: 'M12 8a4 4 0 1 0 0 .01M4 20c1.5-4 4.5-6 8-6s6.5 2 8 6' }
	];
	const active = (href: string) => (href === '/' ? page.url.pathname === '/' : page.url.pathname.startsWith(href));

	onMount(restoreSharing);
</script>

<header class="top">
	<a href="/" class="brand" aria-label="Viagem a Curitiba, início">
		<span class="plane" aria-hidden="true">✈</span>
		<span class="name">Curitiba</span>
		<span class="stamp small">11–18/11</span>
	</a>
	<nav class="desktop" aria-label="Principal">
		{#each items as it}
			<a href={it.href} aria-current={active(it.href) ? 'page' : undefined} style:--c={it.color}>
				<svg viewBox="0 0 24 24" aria-hidden="true"><path d={it.icon} /></svg>{it.label}
			</a>
		{/each}
	</nav>
	{#if loc.sharing}<span class="live" title="Compartilhando sua localização"><span class="dot"></span>Ao vivo</span>{/if}
</header>

{@render children()}

<nav class="dock" aria-label="Principal">
	{#each items as it}
		<a href={it.href} class:primary={it.primary} aria-current={active(it.href) ? 'page' : undefined} style:--c={it.color}>
			<span class="tile"><svg viewBox="0 0 24 24" aria-hidden="true"><path d={it.icon} /></svg></span>
			<span class="label">{it.short}</span>
		</a>
	{/each}
</nav>

<style>
	.top {
		position: sticky; top: 0; z-index: 20; display: flex; align-items: center; gap: 16px;
		padding: calc(10px + env(safe-area-inset-top)) 16px 10px;
		background: color-mix(in srgb, var(--bg) 92%, transparent); backdrop-filter: blur(8px);
		border-bottom: 2.5px dashed var(--line);
	}
	.brand { display: inline-flex; align-items: center; gap: 8px; text-decoration: none; color: var(--ink); }
	.plane { display: grid; place-items: center; width: 36px; height: 36px; border-radius: 12px; background: var(--sea); color: #fff; font-size: 1.1rem; box-shadow: 0 3px 0 var(--sea-dark); transform: rotate(-8deg); }
	.name { font-family: var(--font-display); font-weight: 600; font-size: 1.5rem; }
	.brand .stamp { font-size: 0.75rem; padding: 0 6px; }
	.desktop { display: none; gap: 6px; margin-left: auto; }
	.desktop a {
		display: inline-flex; align-items: center; gap: 6px; padding: 8px 14px; border-radius: 999px; text-decoration: none;
		color: var(--ink); font-family: var(--font-display); font-weight: 500; border: 2.5px solid transparent;
	}
	.desktop a:hover { border-color: var(--line); }
	.desktop a[aria-current='page'] { background: var(--surface); border-color: var(--line); box-shadow: 0 3px 0 var(--shadow); }
	.desktop svg { width: 20px; height: 20px; fill: none; stroke: var(--c); stroke-width: 2.4; stroke-linecap: round; stroke-linejoin: round; }
	.live { margin-left: auto; display: inline-flex; align-items: center; gap: 6px; font-size: 0.8rem; font-weight: 800; color: var(--leaf); background: var(--surface); padding: 4px 10px; border-radius: 999px; border: 2px solid var(--line); }
	.desktop + .live { margin-left: 8px; }
	.dot { width: 9px; height: 9px; border-radius: 50%; background: var(--leaf); animation: pulse 1.6s infinite; }
	@keyframes pulse { 50% { opacity: 0.25; transform: scale(0.7); } }

	.dock {
		position: fixed; z-index: 30; left: 10px; right: 10px; bottom: calc(10px + env(safe-area-inset-bottom));
		height: calc(var(--nav-h) - 10px); display: grid; grid-template-columns: repeat(5, 1fr); align-items: center;
		background: var(--surface); border: 2.5px solid var(--line); border-radius: 28px; box-shadow: 0 5px 0 var(--shadow), 0 10px 24px rgb(0 0 0 / 0.12);
		max-width: 520px; margin: 0 auto;
	}
	.dock a { display: grid; justify-items: center; gap: 2px; text-decoration: none; color: var(--muted); font-size: 0.72rem; font-weight: 800; -webkit-tap-highlight-color: transparent; }
	.tile {
		display: grid; place-items: center; width: 38px; height: 38px; border-radius: 14px; background: var(--c);
		box-shadow: 0 3px 0 rgb(0 0 0 / 0.18); transition: transform 0.2s var(--bounce);
	}
	.tile svg { width: 22px; height: 22px; fill: none; stroke: #fff; stroke-width: 2.4; stroke-linecap: round; stroke-linejoin: round; }
	.dock a[aria-current='page'] { color: var(--ink); }
	.dock a[aria-current='page'] .tile { transform: translateY(-4px) rotate(-6deg) scale(1.08); }
	.dock a:active .tile { transform: scale(0.9); }
	.dock a.primary .tile { width: 52px; height: 52px; border-radius: 50%; margin-top: -22px; border: 4px solid var(--surface); box-shadow: 0 4px 0 var(--sun-dark); }
	.dock a.primary svg { stroke: #4a3410; width: 26px; height: 26px; }
	@media (min-width: 820px) {
		.desktop { display: flex; }
		.dock { display: none; }
		:global(:root) { --nav-h: 0px; }
	}
</style>
