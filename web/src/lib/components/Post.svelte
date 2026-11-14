<script lang="ts">
	import CommentPreview from './CommentPreview.svelte';
	import Avatar from './Avatar.svelte';
	import Icon from './Icon.svelte';
	import LikeButton from './LikeButton.svelte';
	import LikedBy from './LikedBy.svelte';
	import { fmtDuration, fmtTime } from '$lib/format';
	import { visiblePlayback } from '$lib/video';
	import { justZoomed, pinchZoom } from '$lib/zoom';
	import type { FeedMedia, Person } from '$lib/types';

	let {
		items,
		persons,
		meId,
		onopen
	}: { items: FeedMedia[]; persons: Map<string, Person>; meId: string; /** opens the reels at this item */ onopen?: (id: string) => void } = $props();

	const p = $derived(persons.get(items[0].userId));
	let index = $state(0);
	const cur = $derived(items[Math.min(index, items.length - 1)]);

	// local like state per item, re-synced whenever fresh data arrives
	let likes = $state<Record<string, string[]>>({});
	$effect(() => {
		likes = Object.fromEntries(items.map((m) => [m.id, m.likers]));
	});

	// Instagram-like frame: between 4:5 portrait and 1.91:1 landscape, from the first item
	const ratio = $derived.by(() => {
		const f = items[0];
		const r = f.width && f.height ? f.width / f.height : 1;
		return Math.min(1.91, Math.max(0.8, r));
	});

	// at most 5 dots, sliding with the photo (Instagram-style); the ones at the window's edges are smaller
	const DOTS = 5;
	const dotStart = $derived(Math.max(0, Math.min(index - 2, items.length - DOTS)));
	const dotWindow = $derived(Array.from({ length: Math.min(DOTS, items.length) }, (_, k) => dotStart + k));
	const dotSmall = (i: number) =>
		items.length > DOTS && ((i === dotStart && dotStart > 0) || (i === dotStart + DOTS - 1 && dotStart + DOTS < items.length));

	let track: HTMLDivElement;
	/** The first time a carousel shows up, it slides a little to the next photo and back: "there's more". */
	function nudge(node: HTMLElement) {
		if (items.length < 2) return;
		const io = new IntersectionObserver(
			(e) => {
				if (!e[0].isIntersecting) return;
				io.disconnect();
				setTimeout(() => {
					if (node.scrollLeft !== 0) return;
					node.scrollTo({ left: Math.min(70, node.clientWidth * 0.18), behavior: 'smooth' });
					setTimeout(() => node.scrollTo({ left: 0, behavior: 'smooth' }), 450);
				}, 500);
			},
			{ threshold: 0.7 }
		);
		io.observe(node);
		return { destroy: () => io.disconnect() };
	}
	function onScroll() {
		index = Math.round(track.scrollLeft / track.clientWidth);
	}
	function go(i: number) {
		track.scrollTo({ left: i * track.clientWidth, behavior: 'smooth' });
	}

	let likeBtn: LikeButton;
	let bigHeart = $state(0);
	let lastTap = 0;
	let single: ReturnType<typeof setTimeout> | undefined;
	/** Double tap / double click on a photo likes it, with the big heart; a single tap opens the reels. */
	function tap(e: PointerEvent, m: FeedMedia) {
		if (m.kind === 'video' || m.status !== 'ready' || justZoomed()) return;
		const now = e.timeStamp;
		if (now - lastTap < 320) {
			clearTimeout(single);
			likeBtn.set(true);
			bigHeart++;
			lastTap = 0;
		} else {
			lastTap = now;
			clearTimeout(single);
			if (onopen) single = setTimeout(() => onopen(m.id), 320);
		}
	}
</script>

<article class="post card">
	<header class="head">
		<Avatar name={p?.name ?? '?'} color={p?.color ?? '#888'} photo={p?.photo} size={40} />
		<div class="who">
			<strong>{p?.name ?? 'Alguém'}</strong>
			<span class="small muted">
				{fmtTime(items[0].at)}{items.length > 1 && items.at(-1)!.at !== items[0].at ? `–${fmtTime(items.at(-1)!.at)}` : ''}
				{#if cur.lat != null}· <a href="/mapa?foco={cur.lat},{cur.lng}" class="place"><Icon name="pin" size={13} /> no mapa</a>{/if}
			</span>
		</div>
	</header>

	<div class="media" style:aspect-ratio={ratio}>
		<div class="track" bind:this={track} onscroll={onScroll} use:nudge>
			{#each items as m (m.id)}
				<div class="slide" onpointerup={(e) => tap(e, m)} role="presentation" use:pinchZoom>
					{#if (m.status === 'preview' || m.status === 'processing') && m.image}
						<img src={m.image} alt={m.caption || `Foto de ${p?.name ?? ''}`} loading="lazy" draggable="false" />
						<span class="pending"><Icon name="clock" size={14} />
							{m.status === 'preview' ? `${m.kind === 'video' ? 'Vídeo completo' : 'Foto completa'} chega quando ${p?.name ?? 'a pessoa'} estiver no Wi‑Fi` : 'Processando o original…'}</span>
					{:else if m.status !== 'ready'}
						<div class="ph">{m.status === 'failed' ? 'Não foi possível processar' : m.kind === 'video' ? 'Preparando o vídeo…' : 'Processando…'}</div>
					{:else if m.kind === 'video' && m.video}
						<!-- svelte-ignore a11y_media_has_caption -->
						<video src={m.video} poster={m.image ?? undefined} controls playsinline preload="none" use:visiblePlayback></video>
					{:else if m.image}
						<img src={m.image} alt={m.caption || `Foto de ${p?.name ?? ''}`} loading="lazy" draggable="false" />
					{/if}
					{#if m.kind === 'video' && m.durationS && m.status === 'ready'}<span class="dur">{fmtDuration(m.durationS)}</span>{/if}
				</div>
			{/each}
		</div>
		{#key bigHeart}
			{#if bigHeart}<span class="big-heart" aria-hidden="true"><Icon name="heart" size={96} stroke={1.5} /></span>{/if}
		{/key}
		{#if items.length > 1}
			<!-- more photos: a counter on the picture (and the arrows), like Instagram -->
			<span class="count" aria-label="Foto {index + 1} de {items.length}"><Icon name="stack" size={14} /> {index + 1}/{items.length}</span>
		{/if}
		{#if items.length > 1 && index > 0}
			<button class="nav prev" onclick={() => go(index - 1)} aria-label="Anterior">‹</button>
		{/if}
		{#if items.length > 1 && index < items.length - 1}
			<button class="nav next" onclick={() => go(index + 1)} aria-label="Próxima">›</button>
		{/if}
	</div>

	<div class="actions">
		<LikeButton bind:this={likeBtn} target={{ mediaId: cur.id }} likers={likes[cur.id] ?? []} {meId} onchange={(l) => (likes[cur.id] = l)} />
		<a class="act" href="/m/{cur.id}#comentarios" aria-label="Comentários"><Icon name="chat" size={26} /></a>
		{#if onopen && cur.status === 'ready'}
			<button class="act" onclick={() => onopen(cur.id)} aria-label="Abrir em tela cheia"><Icon name="expand" size={24} /></button>
		{:else}
			<a class="act" href="/m/{cur.id}" aria-label="Abrir em tela cheia"><Icon name="expand" size={24} /></a>
		{/if}
		{#if cur.status !== 'preview'}
			<a class="act" href="/api/media/{cur.id}/original" download aria-label="Salvar original" title="Salvar original"><Icon name="download" size={24} /></a>
		{/if}
		{#if items.length > 1}
			<span class="dots" aria-hidden="true">
				{#each dotWindow as i (i)}<i class:on={i === index} class:small={dotSmall(i)}></i>{/each}
			</span>
		{/if}
	</div>

	<div class="text">
		<LikedBy likers={likes[cur.id] ?? []} {persons} {meId} />
		{#if cur.caption}<p class="caption"><strong>{p?.name}</strong> {cur.caption}</p>{/if}
		<CommentPreview first={cur.firstComments ?? []} total={cur.comments} {persons} href="/m/{cur.id}#comentarios" />
	</div>
</article>

<style>
	.post { padding: 0; overflow: hidden; animation: pop-in 0.45s var(--bounce) both; }
	.head { display: flex; align-items: center; gap: 10px; padding: 10px 12px; }
	.who { display: grid; line-height: 1.25; min-width: 0; }
	.who strong { font: 600 1.05rem var(--font-display); }
	.place { display: inline-flex; align-items: center; gap: 2px; font-weight: 800; text-decoration: none; }
	.count {
		position: absolute; right: 10px; top: 10px; display: inline-flex; align-items: center; gap: 4px; padding: 3px 9px; border-radius: 999px;
		background: rgb(0 0 0 / 0.6); color: #fff; font-size: 0.78rem; font-weight: 800; pointer-events: none;
	}
	.media { position: relative; background: #111; border-top: 2.5px solid var(--line); border-bottom: 2.5px solid var(--line); }
	.track { display: flex; width: 100%; height: 100%; overflow-x: auto; scroll-snap-type: x mandatory; scrollbar-width: none; overscroll-behavior-x: contain; }
	.track::-webkit-scrollbar { display: none; }
	.slide { cursor: pointer; position: relative; flex: 0 0 100%; height: 100%; scroll-snap-align: center; user-select: none; -webkit-user-select: none; touch-action: pan-x pan-y; }
	.slide img, .slide video { width: 100%; height: 100%; object-fit: cover; display: block; }
	.slide video { object-fit: contain; background: #000; }
	.ph { position: absolute; inset: 0; display: grid; place-items: center; color: #ddd; font-weight: 800; text-align: center; padding: 16px; background: repeating-linear-gradient(135deg, #222 0 14px, #2a2a2a 14px 28px); }
	.pending {
		position: absolute; left: 8px; right: 8px; bottom: 8px; display: flex; align-items: center; gap: 6px; padding: 6px 10px;
		border-radius: 12px; background: rgb(0 0 0 / 0.6); color: #fff; font-size: 0.8rem; font-weight: 800; pointer-events: none;
	}
	.dur { position: absolute; left: 10px; top: 10px; background: rgb(0 0 0 / 0.6); color: #fff; font-size: 0.75rem; font-weight: 800; padding: 2px 8px; border-radius: 999px; pointer-events: none; }
	.big-heart { position: absolute; left: 50%; top: 50%; translate: -50% -50%; color: #fff; pointer-events: none; filter: drop-shadow(0 4px 12px rgb(0 0 0 / 0.4)); animation: big-heart 0.9s ease-out forwards; }
	.big-heart :global(svg) { fill: #fff; }
	@keyframes big-heart {
		0% { transform: scale(0); opacity: 0; }
		15% { transform: scale(1.2); opacity: 1; }
		30% { transform: scale(0.95); }
		45%, 75% { transform: scale(1); opacity: 1; }
		100% { transform: scale(1.1) translateY(-30px); opacity: 0; }
	}
	.nav { position: absolute; top: 50%; translate: 0 -50%; width: 28px; height: 28px; border-radius: 50%; border: 0; background: rgb(255 252 240 / 0.75); color: #333; font-size: 1.3rem; line-height: 1; cursor: pointer; display: grid; place-items: center; box-shadow: 0 2px 6px rgb(0 0 0 / 0.3); }
	.prev { left: 8px; }
	.next { right: 8px; }
	@media (hover: hover) { .nav { width: 34px; height: 34px; background: rgb(255 252 240 / 0.88); } }
	.actions { display: flex; align-items: center; gap: 2px; padding: 4px 6px 0; position: relative; }
	button.act { border: 0; background: none; cursor: pointer; padding: 0; }
	.act { display: grid; place-items: center; min-width: 44px; min-height: 44px; color: var(--ink); }
	/* in the row, after the buttons (centered it ran into the 4th button on phones) */
	.dots { margin-left: auto; margin-right: 12px; display: flex; align-items: center; gap: 5px; }
	.dots i { width: 7px; height: 7px; border-radius: 50%; background: var(--line); transition: background 0.2s, transform 0.2s; }
	.dots i.on { background: var(--sea); transform: scale(1.25); }
	.dots i.small { transform: scale(0.6); }
	.text { display: grid; gap: 4px; padding: 0 14px 14px; }
	.caption { margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; }
	.caption strong { font-weight: 800; margin-right: 4px; }
</style>
