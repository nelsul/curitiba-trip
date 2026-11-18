<script lang="ts">
	import Avatar from '$lib/components/Avatar.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import Story from '$lib/components/Story.svelte';
	import { fmtLongDay, fmtTime } from '$lib/format';
	import type { FeedMedia } from '$lib/types';

	let { data } = $props();
	const byId = $derived(new Map(data.persons.map((p) => [p.id, p])));
	let playing = $state<number | null>(null);

	/** Day → starred photos/videos, oldest first (the server already sends them in that order). */
	const days = $derived.by(() => {
		const out = new Map<string, { m: FeedMedia; i: number }[]>();
		data.items.forEach((m, i) => (out.get(m.day) ?? out.set(m.day, []).get(m.day)!).push({ m, i }));
		return [...out.entries()];
	});
	const names = (ids: string[]) => ids.map((id) => byId.get(id)?.name ?? '?').join(', ');
</script>

<svelte:head><title>Retrospectiva · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<div class="title-row"><span class="title-icon"><Icon name="sparkle" size={26} /></span><h1>Retrospectiva</h1></div>
	<p class="muted intro">Os favoritos de todo mundo, na ordem em que aconteceram. Toque na <span class="star-ic"><Icon name="star" size={15} /></span> de uma foto ou vídeo no diário para pôr aqui.</p>

	{#if data.items.length}
		<button class="play card" onclick={() => (playing = 0)}>
			{#if data.items[0].image}<img src={data.items[0].image} alt="" />{/if}
			<span class="ov">
				<span class="pl"><Icon name="play" size={34} /></span>
				<strong>Ver a retrospectiva</strong>
				<span class="small">{data.items.length} {data.items.length === 1 ? 'momento' : 'momentos'}</span>
			</span>
		</button>

		{#each days as [d, list] (d)}
			<section class="day">
				<h2 class="day-title">{fmtLongDay(d)}</h2>
				<ul class="favs">
					{#each list as { m, i } (m.id)}
						{@const author = byId.get(m.userId)}
						<li>
							<a class="thumb" href="/m/{m.id}">
								{#if m.thumb ?? m.image}<img src={m.thumb ?? m.image} alt={m.caption || `Foto de ${author?.name ?? ''}`} loading="lazy" />{/if}
								{#if m.kind === 'video'}<span class="vid"><Icon name="play" size={14} /></span>{/if}
							</a>
							<div class="meta">
								<span class="small"><strong>{author?.name ?? 'Alguém'}</strong> · {fmtTime(m.at)}</span>
								{#if m.caption}<span class="small cap">{m.caption}</span>{/if}
								<span class="by">
									<span class="faces">{#each m.favs as id (id)}{@const p = byId.get(id)}<Avatar name={p?.name ?? '?'} color={p?.color ?? '#888'} photo={p?.photo} size={22} />{/each}</span>
									<span class="small"><Icon name="star" size={12} /> {names(m.favs)}</span>
								</span>
							</div>
							<button class="ib" onclick={() => (playing = i)} aria-label="Ver na retrospectiva"><Icon name="play" size={16} /></button>
						</li>
					{/each}
				</ul>
			</section>
		{/each}
	{:else}
		<div class="card empty">
			<Icon name="star" size={40} />
			<p>Nenhum favorito ainda. No diário ou no modo tela cheia, toque na estrela das fotos e vídeos que merecem entrar aqui.</p>
		</div>
	{/if}
</main>

{#if playing !== null}<Story items={data.items.slice(playing)} persons={byId} onclose={() => (playing = null)} />{/if}

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
	.favs { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
	.favs li { display: flex; align-items: center; gap: 10px; padding: 8px; background: var(--surface); border: 2px solid var(--line); border-radius: 16px; }
	.thumb { position: relative; flex: none; width: 72px; height: 72px; border-radius: 12px; overflow: hidden; background: #111; }
	.thumb img { width: 100%; height: 100%; object-fit: cover; display: block; }
	.vid { position: absolute; right: 4px; bottom: 4px; display: grid; place-items: center; width: 22px; height: 22px; border-radius: 50%; background: rgb(0 0 0 / 0.6); color: #fff; }
	.vid :global(svg) { fill: currentColor; }
	.meta { flex: 1; min-width: 0; display: grid; gap: 3px; }
	.cap { color: var(--muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.by { display: flex; align-items: center; gap: 6px; min-width: 0; }
	.by .small { display: inline-flex; align-items: center; gap: 3px; color: var(--sun); font-weight: 800; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.by :global(svg) { fill: currentColor; flex: none; }
	.faces { display: flex; flex: none; }
	.faces > :global(*) + :global(*) { margin-left: -7px; }
	.ib { flex: none; width: 40px; height: 40px; border: 2px solid var(--line); border-radius: 12px; background: var(--surface-2); color: var(--ink); display: grid; place-items: center; cursor: pointer; }
	.ib :global(svg) { fill: currentColor; }
</style>
