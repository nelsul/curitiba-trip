<script lang="ts">
	import { onMount } from 'svelte';
	import Avatar from './Avatar.svelte';
	import Icon from './Icon.svelte';
	import { fmtLongDay } from '$lib/format';
	import type { FeedMedia, Person } from '$lib/types';

	/**
	 * The Retrospectiva as stories (like a year-in-review): an opening card, the chosen photos/videos in order and a
	 * closing card. Tap right/left to move, hold to pause; photos stay 5 s, videos play to the end.
	 */
	let { items, persons, onclose }: { items: FeedMedia[]; persons: Map<string, Person>; onclose: () => void } = $props();

	const PHOTO_MS = 5000;
	const total = $derived(items.length + 2);
	let i = $state(0);
	let progress = $state(0);
	let paused = $state(false);
	let video = $state<HTMLVideoElement>();
	let last = 0;
	let raf = 0;
	const cur = $derived(i > 0 && i <= items.length ? items[i - 1] : null);
	const people = $derived(new Set(items.map((m) => m.userId)).size);
	const daysCount = $derived(new Set(items.map((m) => m.day)).size);

	function go(n: number) {
		if (n < 0) n = 0;
		if (n >= total) return onclose();
		i = n;
		progress = 0;
	}
	function frame(t: number) {
		const dt = last ? t - last : 0;
		last = t;
		if (!paused) {
			if (cur?.kind === 'video' && video) progress = video.duration ? video.currentTime / video.duration : 0;
			else progress += dt / PHOTO_MS;
			if (progress >= 1 && !(cur?.kind === 'video')) go(i + 1);
		}
		raf = requestAnimationFrame(frame);
	}
	onMount(() => {
		const prev = document.body.style.overflow;
		document.body.style.overflow = 'hidden';
		raf = requestAnimationFrame(frame);
		return () => {
			cancelAnimationFrame(raf);
			document.body.style.overflow = prev;
		};
	});
	$effect(() => {
		if (!video) return;
		if (paused) video.pause();
		else video.play().catch(() => {});
	});

	let downAt = 0;
	function down() {
		downAt = performance.now();
		paused = true;
	}
	function up(e: PointerEvent) {
		paused = false;
		if (performance.now() - downAt > 300) return; // it was a hold
		const x = e.clientX / (e.currentTarget as HTMLElement).clientWidth;
		go(x < 0.33 ? i - 1 : i + 1);
	}
	function key(e: KeyboardEvent) {
		if (e.key === 'ArrowRight' || e.key === ' ') go(i + 1);
		else if (e.key === 'ArrowLeft') go(i - 1);
		else if (e.key === 'Escape') onclose();
	}
</script>

<svelte:window onkeydown={key} />

<div class="story" role="dialog" aria-modal="true" aria-label="Retrospectiva, {i + 1} de {total}">
	<div class="bars" aria-hidden="true">
		{#each { length: total } as _, n}<span><i style:width="{n < i ? 100 : n === i ? Math.min(1, progress) * 100 : 0}%"></i></span>{/each}
	</div>
	<button class="close" onclick={onclose} aria-label="Fechar"><Icon name="close" size={22} /></button>

	<div class="stage" onpointerdown={down} onpointerup={up} onpointercancel={() => (paused = false)} role="presentation">
		{#key i}
			{#if i === 0}
				<div class="card-slide intro">
					<span class="spark"><Icon name="sparkle" size={64} /></span>
					<p class="kicker">Retrospectiva</p>
					<h2>Curitiba<br />2026</h2>
					<p class="stats"><strong>{items.length}</strong> momentos · <strong>{daysCount}</strong> {daysCount === 1 ? 'dia' : 'dias'} · <strong>{people}</strong> {people === 1 ? 'pessoa' : 'pessoas'}</p>
				</div>
			{:else if cur}
				{@const p = persons.get(cur.userId)}
				<div class="media">
					{#if cur.kind === 'video' && cur.video}
						<!-- svelte-ignore a11y_media_has_caption -->
						<video bind:this={video} src={cur.video} poster={cur.image ?? undefined} playsinline autoplay onended={() => go(i + 1)}></video>
					{:else if cur.image}
						<img src={cur.image} alt={cur.caption || `Foto de ${p?.name ?? ''}`} draggable="false" />
					{/if}
					<div class="cap">
						<div class="who"><Avatar name={p?.name ?? '?'} color={p?.color ?? '#888'} photo={p?.photo} size={32} /><strong>{p?.name ?? 'Alguém'}</strong></div>
						<span class="small day">{fmtLongDay(cur.day)}</span>
						{#if cur.caption}<p>{cur.caption}</p>{/if}
					</div>
				</div>
			{:else}
				<div class="card-slide outro">
					<span class="spark"><Icon name="heart" size={64} /></span>
					<h2>Obrigado por<br />essa viagem!</h2>
					<p>Com amor, de Curitiba.</p>
				</div>
			{/if}
		{/key}
	</div>
</div>

<style>
	.story { position: fixed; inset: 0; z-index: 80; background: #000; color: #fff; user-select: none; -webkit-user-select: none; }
	.bars { position: absolute; z-index: 3; top: calc(10px + env(safe-area-inset-top)); left: 10px; right: 10px; display: flex; gap: 4px; max-width: 600px; margin: 0 auto; }
	.bars span { flex: 1; height: 3px; border-radius: 3px; background: rgb(255 255 255 / 0.35); overflow: hidden; }
	.bars i { display: block; height: 100%; background: #fff; }
	.close { position: absolute; z-index: 4; top: calc(22px + env(safe-area-inset-top)); right: 10px; width: 44px; height: 44px; border: 0; border-radius: 50%; background: rgb(0 0 0 / 0.35); color: #fff; display: grid; place-items: center; cursor: pointer; }
	.stage { position: absolute; inset: 0; max-width: 600px; margin: 0 auto; touch-action: none; }
	.media { position: absolute; inset: 0; display: grid; place-items: center; animation: zoom 6s ease-out both; }
	.media img, .media video { width: 100%; height: 100%; object-fit: contain; }
	@keyframes zoom { from { transform: scale(1.06); opacity: 0; } 8% { opacity: 1; } to { transform: scale(1); } }
	.cap { position: absolute; left: 0; right: 0; bottom: 0; padding: 60px 18px calc(24px + env(safe-area-inset-bottom)); background: linear-gradient(transparent, rgb(0 0 0 / 0.7)); display: grid; gap: 4px; }
	.cap p { margin: 0; }
	.who { display: flex; align-items: center; gap: 8px; }
	.who strong { font: 600 1.1rem var(--font-display); }
	.day::first-letter { text-transform: uppercase; }
	.card-slide { position: absolute; inset: 0; display: grid; place-content: center; justify-items: center; gap: 12px; text-align: center; padding: 24px; animation: pop-in 0.6s var(--bounce) both; }
	.intro { background: radial-gradient(circle at 30% 20%, var(--berry), transparent 60%), radial-gradient(circle at 80% 80%, var(--sea-dark), transparent 55%), var(--bg); }
	.outro { background: radial-gradient(circle at 70% 25%, var(--sun-dark), transparent 60%), radial-gradient(circle at 20% 85%, var(--berry), transparent 55%), var(--bg); }
	.card-slide h2 { margin: 0; font: 600 clamp(2.6rem, 12vw, 4.2rem) / 1.05 var(--font-display); color: #fff; }
	.kicker { margin: 0; font-weight: 800; letter-spacing: 0.2em; text-transform: uppercase; color: var(--sun); }
	.stats { margin: 0; font-size: 1.05rem; }
	.stats strong { color: var(--sun); font-size: 1.3rem; }
	.spark { color: var(--sun); animation: bob 3s ease-in-out infinite; }
</style>
