<script lang="ts">
	import { onMount } from 'svelte';
	import Icon from '$lib/components/Icon.svelte';
	import LocationPicker from '$lib/components/LocationPicker.svelte';
	import WeatherCard from '$lib/components/WeatherCard.svelte';
	import { CATEGORY, TRANSPORT, placeUrl, priceSigns, uberUrl } from '$lib/itinerary';
	import { fmtLongDay } from '$lib/format';
	import type { WeatherDay } from '$lib/weather';

	let { data } = $props();
	const p = $derived(data.place);
	const cat = $derived(CATEGORY[p.category]);
	const signs = $derived(priceSigns(p.priceLevel));
	let photo = $state(0);
	let track = $state<HTMLDivElement>();
	let full = $state<string | null>(null);

	const linkLabel = $derived.by(() => {
		try {
			const h = new URL(p.link).hostname.replace(/^www\./, '');
			return h.includes('instagram') ? 'Instagram' : h;
		} catch {
			return 'Site';
		}
	});

	let weather = $state<Record<string, WeatherDay>>({});
	onMount(() => {
		if (!data.stops.length) return;
		fetch('/api/weather')
			.then((r) => (r.ok ? r.json() : { days: [] }))
			.then((w: { days: WeatherDay[] }) => (weather = Object.fromEntries(w.days.map((d) => [d.date, d]))))
			.catch(() => {});
	});
	const go = (i: number) => track?.scrollTo({ left: i * track.clientWidth, behavior: 'smooth' });
</script>

<svelte:head><title>{p.name} · Roteiro</title></svelte:head>

<main class="page narrow place">
	<a href="/roteiro?aba=lugares" class="back btn small secondary">← Lugares</a>

	<div class="hero" class:empty={!p.photos.length}>
		{#if p.photos.length}
			<div class="track" bind:this={track} onscroll={() => track && (photo = Math.round(track.scrollLeft / track.clientWidth))}>
				{#each p.photos as ph, i (ph.id)}
					<button class="ph" onclick={() => (full = ph.url)} aria-label="Ver foto {i + 1} de {p.photos.length} em tela cheia">
						<img src={ph.url} alt={i === 0 ? p.name : ''} draggable="false" />
					</button>
				{/each}
			</div>
			{#if p.photos.length > 1}
				<span class="count small">{photo + 1}/{p.photos.length}</span>
				{#if photo > 0}<button class="nav prev" onclick={() => go(photo - 1)} aria-label="Foto anterior">‹</button>{/if}
				{#if photo < p.photos.length - 1}<button class="nav next" onclick={() => go(photo + 1)} aria-label="Próxima foto">›</button>{/if}
			{/if}
		{:else}
			<span class="none"><Icon name="camera" size={34} /> Sem fotos ainda</span>
		{/if}
		<span class="cat" style:--c={cat.color}>{cat.label}</span>
	</div>

	{#if p.photos.length > 1}
		<div class="thumbs">
			{#each p.photos as ph, i (ph.id)}
				<button class:on={i === photo} onclick={() => go(i)} aria-label="Foto {i + 1}"><img src={ph.url} alt="" loading="lazy" /></button>
			{/each}
		</div>
	{/if}

	<h1>{p.name}</h1>
	{#if p.address}<p class="addr muted"><Icon name="pin" size={16} /> {p.address}</p>{/if}

	<div class="actions">
		<a class="btn uber" href={uberUrl(p)} target="_blank" rel="noopener"><Icon name="car" size={20} /> Pedir Uber</a>
		<a class="btn secondary" href={placeUrl(p)} target="_blank" rel="noopener"><Icon name="map" size={20} /> Google Maps</a>
		{#if p.link}<a class="btn secondary" href={p.link} target="_blank" rel="noopener"><Icon name="external" size={18} /> {linkLabel}</a>{/if}
	</div>

	<section class="card facts">
		{#if p.hours}<div><span class="ico"><Icon name="clock" size={20} /></span><div><strong>Horário</strong><p>{p.hours}</p></div></div>{/if}
		{#if p.price || signs}<div><span class="ico"><Icon name="wallet" size={20} /></span><div><strong>Preço</strong><p>{#if signs}<b class="signs">{signs}</b> {/if}{p.price}</p></div></div>{/if}
		{#if !p.hours && !p.price && !signs}<p class="muted">Sem horário ou preço anotados.</p>{/if}
	</section>

	{#if p.description}<section class="desc"><h2>Sobre</h2><p>{p.description}</p></section>{/if}

	<section>
		<h2>No roteiro</h2>
		{#each data.stops as s (s.id)}
			<a class="card day" href="/roteiro">
				<div class="dtop">
					<strong class="cap">{fmtLongDay(s.date)}</strong>
					{#if s.visitedAt}<span class="been"><Icon name="check" size={14} /> Fomos!</span>{/if}
				</div>
				<span class="small muted">{[s.dayTitle, s.time, TRANSPORT[s.transport].label].filter(Boolean).join(' · ')}</span>
				{#if s.note}<p class="small">{s.note}</p>{/if}
				{#if weather[s.date]}<WeatherCard day={weather[s.date]} compact />{/if}
			</a>
		{:else}
			<p class="muted">Ainda não está em nenhum dia.</p>
		{/each}
	</section>

	<section>
		<h2>Onde fica</h2>
		<LocationPicker lat={p.lat} lng={p.lng} />
	</section>
</main>

{#if full}
	<button class="lightbox" onclick={() => (full = null)} aria-label="Fechar foto"><img src={full} alt="" /></button>
{/if}

<style>
	.back { margin-bottom: 10px; }
	.hero { position: relative; aspect-ratio: 4 / 3; border-radius: var(--radius); overflow: hidden; border: 2.5px solid var(--line); background: var(--surface-2); }
	.track { display: flex; height: 100%; overflow-x: auto; scroll-snap-type: x mandatory; scrollbar-width: none; }
	.track::-webkit-scrollbar { display: none; }
	.ph { flex: 0 0 100%; height: 100%; padding: 0; border: 0; background: none; scroll-snap-align: center; cursor: zoom-in; }
	.ph img { width: 100%; height: 100%; object-fit: cover; display: block; }
	.none { position: absolute; inset: 0; display: grid; place-content: center; justify-items: center; gap: 6px; color: var(--muted); font-weight: 800; }
	.cat { position: absolute; top: 10px; left: 10px; padding: 2px 10px; border-radius: 999px; font-size: 0.8rem; font-weight: 800; background: var(--c); color: #fff; }
	.count { position: absolute; top: 10px; right: 10px; background: rgb(0 0 0 / 0.55); color: #fff; border-radius: 999px; padding: 1px 9px; font-weight: 800; }
	.nav { position: absolute; top: 50%; translate: 0 -50%; width: 40px; height: 40px; border-radius: 50%; border: 0; background: rgb(0 0 0 / 0.45); color: #fff; font-size: 1.5rem; cursor: pointer; display: grid; place-items: center; }
	.prev { left: 8px; }
	.next { right: 8px; }
	.thumbs { display: flex; gap: 6px; overflow-x: auto; margin-top: 8px; scrollbar-width: none; }
	.thumbs button { flex: none; width: 60px; height: 60px; padding: 0; border: 2.5px solid transparent; border-radius: 12px; overflow: hidden; background: none; cursor: pointer; opacity: 0.6; }
	.thumbs button.on { border-color: var(--sea); opacity: 1; }
	.thumbs img { width: 100%; height: 100%; object-fit: cover; }
	h1 { margin: 16px 0 4px; }
	.addr { display: flex; gap: 6px; align-items: flex-start; margin: 0; }
	.addr :global(svg) { flex: none; margin-top: 3px; }
	.actions { display: flex; flex-wrap: wrap; gap: 8px; margin: 14px 0; }
	.btn.uber { --b: #1b1b1b; --b-dark: #000; --b-ink: #fff; }
	.facts { display: grid; gap: 12px; }
	.facts > div { display: flex; gap: 12px; align-items: flex-start; }
	.facts p { margin: 2px 0 0; white-space: pre-wrap; }
	.ico { display: grid; place-items: center; width: 38px; height: 38px; border-radius: 12px; background: var(--surface-2); color: var(--sea); flex: none; }
	.signs { color: var(--sun); letter-spacing: 0.05em; }
	section { margin-top: 18px; }
	h2 { margin: 0 0 8px; font-size: 1.2rem; }
	.desc p { margin: 0; white-space: pre-wrap; line-height: 1.5; }
	.day { display: grid; gap: 2px; text-decoration: none; color: var(--ink); margin-bottom: 10px; }
	.dtop { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
	.day p { margin: 4px 0 0; }
	.cap::first-letter { text-transform: uppercase; }
	.been { display: inline-flex; align-items: center; gap: 3px; padding: 1px 9px; border-radius: 999px; font-size: 0.78rem; font-weight: 800; background: var(--leaf); color: var(--on-leaf); }
	.lightbox { position: fixed; inset: 0; z-index: 100; display: grid; place-items: center; background: rgb(0 0 0 / 0.92); border: 0; padding: 12px; cursor: zoom-out; }
	.lightbox img { max-width: 100%; max-height: 100%; object-fit: contain; }
</style>
