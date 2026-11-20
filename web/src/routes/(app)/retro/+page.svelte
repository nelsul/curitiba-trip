<script lang="ts">
	import { invalidate, pushState } from '$app/navigation';
	import { page } from '$app/state';
	import Icon from '$lib/components/Icon.svelte';
	import Story from '$lib/components/Story.svelte';
	import MediaGrid from '$lib/components/MediaGrid.svelte';
	import ReelsViewer from '$lib/components/ReelsViewer.svelte';
	import FrameMaker from '$lib/components/FrameMaker.svelte';
	import { fmtLongDay } from '$lib/format';
	import type { FeedMedia } from '$lib/types';

	let { data } = $props();
	const byId = $derived(new Map(data.persons.map((p) => [p.id, p])));
	let playing = $state<number | null>(null);
	let framing = $state<string[] | null>(null);

	/** Day → starred photos/videos, oldest first (the server already sends them in that order). */
	const days = $derived.by(() => {
		const out = new Map<string, FeedMedia[]>();
		for (const m of data.items) (out.get(m.day) ?? out.set(m.day, []).get(m.day)!).push(m);
		return [...out.entries()];
	});
	/** the cover: the most starred moment (the oldest of them on a tie) */
	const cover = $derived(data.items.reduce<FeedMedia | null>((best, m) => (!best || m.favs.length > best.favs.length ? m : best), null));

	// tapping a photo opens the reels (a shallow route, so the phone's back button closes them)
	const reel = $derived((page.state as { reel?: string }).reel ?? null);
	const openReel = (id: string) => {
		if (!reel) pushState('', { reel: id });
	};
	async function remove(id: string) {
		if (!confirm('Apagar esta foto/vídeo para todo mundo? Não dá para desfazer.')) return;
		const r = await fetch(`/api/media/${id}`, { method: 'DELETE' });
		if (!r.ok) return alert((await r.json().catch(() => null))?.message ?? 'Não foi possível apagar.');
		if (data.items.length <= 1) history.back();
		void invalidate('app:retro');
	}
</script>

<svelte:head><title>Retrospectiva · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<div class="title-row"><span class="title-icon"><Icon name="sparkle" size={26} /></span><h1>Retrospectiva</h1></div>
	<p class="muted intro">Os favoritos de todo mundo, na ordem em que aconteceram. Toque na <span class="star-ic"><Icon name="star" size={15} /></span> de uma foto ou vídeo no diário para pôr aqui.</p>

	{#if data.items.length}
		<button class="play card" onclick={() => (playing = 0)}>
			{#if cover?.image}<img src={cover.image} alt="" />{/if}
			<span class="ov">
				<span class="pl"><Icon name="play" size={34} /></span>
				<strong>Ver a retrospectiva</strong>
				<span class="small">{data.items.length} {data.items.length === 1 ? 'momento' : 'momentos'}</span>
			</span>
		</button>

		{#each days as [d, list] (d)}
			<section class="day">
				<h2 class="day-title">{fmtLongDay(d)}</h2>
				<MediaGrid media={list} onopen={openReel} />
			</section>
		{/each}
	{:else}
		<div class="card empty">
			<Icon name="star" size={40} />
			<p>Nenhum favorito ainda. No diário ou no modo tela cheia, toque na estrela das fotos e vídeos que merecem entrar aqui.</p>
		</div>
	{/if}
</main>

{#if reel}
	<ReelsViewer media={data.items} start={reel} persons={byId} meId={data.me.id} isAdmin={data.me.isAdmin} onclose={() => history.back()}
		onshare={(id) => (framing = [id])} ondelete={remove} />
{/if}
{#if playing !== null}<Story items={data.items.slice(playing)} persons={byId} onclose={() => (playing = null)} />{/if}
{#if framing}<FrameMaker ids={framing} onclose={() => (framing = null)} />{/if}

<style>
	.intro { margin: 0 0 14px; }
	.star-ic { display: inline-flex; vertical-align: -2px; color: var(--sun); }
	.star-ic :global(svg) { fill: currentColor; }
	.play { position: relative; display: block; width: 100%; aspect-ratio: 16 / 10; padding: 0; overflow: hidden; cursor: pointer; border-color: var(--sun); margin-bottom: 18px; }
	.play img { width: 100%; height: 100%; object-fit: cover; display: block; filter: brightness(0.6); }
	.ov { position: absolute; inset: 0; display: grid; place-content: center; justify-items: center; gap: 6px; color: #fff; background: radial-gradient(circle, transparent, rgb(0 0 0 / 0.4)); }
	.ov strong { font: 600 1.6rem var(--font-display); }
	.pl { display: grid; place-items: center; width: 68px; height: 68px; border-radius: 50%; background: var(--sun); color: var(--on-sun); animation: bob 3s ease-in-out infinite; }
	.pl :global(svg) { fill: currentColor; }
	.empty { display: grid; justify-items: center; gap: 8px; text-align: center; color: var(--muted); }
	.empty :global(svg) { color: var(--sun); }
	.empty p { margin: 0; max-width: 34ch; }
	.day { margin-bottom: 20px; }
	.day-title { font-size: 1.05rem; margin: 0 0 8px; }
	.day-title::first-letter { text-transform: uppercase; }
	@media (max-width: 520px) {
		/* edge-to-edge grid on phones, like "Todas as fotos" */
		.day :global(.grid) { margin: 0 -16px; }
	}
</style>
