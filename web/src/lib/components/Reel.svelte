<script lang="ts">
	import Avatar from './Avatar.svelte';
	import Icon from './Icon.svelte';
	import LikeButton from './LikeButton.svelte';
	import { fmtDayMonth, fmtTime } from '$lib/format';
	import { visiblePlayback } from '$lib/video';
	import type { FeedMedia, Person } from '$lib/types';

	let {
		m,
		person,
		meId,
		muted = $bindable()
	}: { m: FeedMedia; person: Person | undefined; meId: string; muted: boolean } = $props();

	let likers = $state<string[]>([]);
	$effect(() => {
		likers = m.likers;
	});

	let video = $state<HTMLVideoElement>();
	let paused = $state(true);
	let likeBtn: LikeButton;
	let bigHeart = $state(0);
	let lastTap = 0;
	let single: ReturnType<typeof setTimeout> | undefined;

	/** Double tap likes (with the big heart); a single tap on a video pauses/plays it. */
	function tap(e: PointerEvent) {
		if ((e.target as HTMLElement).closest('a, button')) return;
		if (e.timeStamp - lastTap < 300) {
			clearTimeout(single);
			likeBtn.set(true);
			bigHeart++;
			lastTap = 0;
			return;
		}
		lastTap = e.timeStamp;
		if (video) {
			const v = video;
			single = setTimeout(() => (v.paused ? v.play().catch(() => {}) : v.pause()), 300);
		}
	}
</script>

<section class="reel" onpointerup={tap} role="presentation" aria-label="{m.kind === 'video' ? 'Vídeo' : 'Foto'} de {person?.name ?? 'alguém'}">
	{#if m.kind === 'video' && m.video}
		<!-- svelte-ignore a11y_media_has_caption -->
		<video
			bind:this={video}
			bind:muted
			bind:paused
			src={m.video}
			poster={m.image ?? undefined}
			playsinline
			loop
			preload="none"
			use:visiblePlayback={{ autoplay: true }}
		></video>
		{#if paused}<span class="play" aria-hidden="true"><Icon name="play" size={56} stroke={1.6} /></span>{/if}
		<button class="sound" onclick={() => (muted = !muted)} aria-label={muted ? 'Ligar o som' : 'Desligar o som'}>
			<Icon name={muted ? 'mute' : 'sound'} size={20} />
		</button>
	{:else if m.image}
		<img src={m.image} alt={m.caption || `Foto de ${person?.name ?? ''}`} loading="lazy" draggable="false" />
	{/if}

	{#key bigHeart}
		{#if bigHeart}<span class="big-heart" aria-hidden="true"><Icon name="heart" size={96} stroke={1.5} /></span>{/if}
	{/key}

	<div class="rail">
		<span class="like"><LikeButton bind:this={likeBtn} target={{ mediaId: m.id }} {likers} {meId} size={30} onchange={(l) => (likers = l)} /></span>
		{#if likers.length}<span class="n">{likers.length}</span>{/if}
		<a href="/m/{m.id}#comentarios" aria-label="Comentários"><Icon name="chat" size={28} /></a>
		{#if m.comments}<span class="n">{m.comments}</span>{/if}
		<a href="/m/{m.id}" aria-label="Abrir detalhes"><Icon name="expand" size={26} /></a>
	</div>

	<div class="info">
		<div class="who">
			<Avatar name={person?.name ?? '?'} color={person?.color ?? '#888'} photo={person?.photo} size={36} />
			<strong>{person?.name ?? 'Alguém'}</strong>
			<span class="when">{fmtDayMonth(m.at)} · {fmtTime(m.at)}</span>
		</div>
		{#if m.caption}<p class="caption">{m.caption}</p>{/if}
		{#if m.lat != null}<a class="place" href="/mapa?foco={m.lat},{m.lng}"><Icon name="pin" size={14} /> no mapa</a>{/if}
	</div>
</section>

<style>
	.reel {
		position: relative; height: 100%; scroll-snap-align: start; scroll-snap-stop: always; overflow: hidden;
		background: #000; display: grid; place-items: center; user-select: none; -webkit-user-select: none;
	}
	.reel img, .reel video { width: 100%; height: 100%; object-fit: contain; display: block; }
	.play { position: absolute; color: #fff; opacity: 0.85; pointer-events: none; filter: drop-shadow(0 2px 8px rgb(0 0 0 / 0.5)); }
	.play :global(svg) { fill: #fff; }
	.sound {
		position: absolute; top: 12px; right: 12px; display: grid; place-items: center; width: 44px; height: 44px;
		border: 0; border-radius: 50%; background: rgb(0 0 0 / 0.45); color: #fff; cursor: pointer;
	}
	.big-heart { position: absolute; left: 50%; top: 50%; translate: -50% -50%; color: #fff; pointer-events: none; filter: drop-shadow(0 4px 12px rgb(0 0 0 / 0.4)); animation: big-heart 0.9s ease-out forwards; }
	.big-heart :global(svg) { fill: #fff; }
	@keyframes big-heart {
		0% { transform: scale(0); opacity: 0; }
		15% { transform: scale(1.2); opacity: 1; }
		30% { transform: scale(0.95); }
		45%, 75% { transform: scale(1); opacity: 1; }
		100% { transform: scale(1.1) translateY(-30px); opacity: 0; }
	}
	.rail {
		position: absolute; right: 8px; bottom: 24px; display: grid; justify-items: center; gap: 2px; color: #fff;
		filter: drop-shadow(0 1px 3px rgb(0 0 0 / 0.6));
	}
	.rail a { display: grid; place-items: center; min-width: 44px; min-height: 44px; color: #fff; margin-top: 8px; }
	.like { --ink: #fff; color: #fff; }
	.n { font-size: 0.8rem; font-weight: 800; margin-top: -6px; }
	.info {
		position: absolute; left: 0; right: 64px; bottom: 0; padding: 48px 14px 18px; display: grid; gap: 6px; color: #fff;
		background: linear-gradient(transparent, rgb(0 0 0 / 0.65)); pointer-events: none;
	}
	.info a { pointer-events: auto; }
	.who { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
	.who strong { font: 600 1.05rem var(--font-display); }
	.when { font-size: 0.8rem; opacity: 0.85; }
	.caption { margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; display: -webkit-box; -webkit-line-clamp: 3; line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
	.place { display: inline-flex; align-items: center; gap: 3px; width: fit-content; color: #fff; font-weight: 800; font-size: 0.85rem; text-decoration: none; }
</style>
