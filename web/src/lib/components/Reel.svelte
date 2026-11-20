<script lang="ts">
	import { justZoomed, pinchZoom } from '$lib/zoom';
	import Avatar from './Avatar.svelte';
	import Icon from './Icon.svelte';
	import LikeButton from './LikeButton.svelte';
	import FavButton from './FavButton.svelte';
	import { fmtDayMonth, fmtTime } from '$lib/format';
	import { visiblePlayback } from '$lib/video';
	import type { FeedMedia, Person } from '$lib/types';

	let {
		m,
		person,
		meId,
		muted = $bindable(),
		onshare,
		ondelete
	}: {
		m: FeedMedia;
		person: Person | undefined;
		meId: string;
		muted: boolean;
		/** photos: put it in a frame and share */
		onshare?: () => void;
		/** owner or admin */
		ondelete?: () => void;
	} = $props();

	let likers = $state<string[]>([]);
	let favs = $state<string[]>([]);
	$effect(() => {
		likers = m.likers;
		favs = m.favs ?? [];
	});

	let video = $state<HTMLVideoElement>();
	let paused = $state(true);
	let likeBtn: LikeButton;
	let bigHeart = $state(0);
	let lastTap = 0;
	let single: ReturnType<typeof setTimeout> | undefined;

	/** Double tap likes (with the big heart); a single tap on a video pauses/plays it. */
	function tap(e: PointerEvent) {
		if ((e.target as HTMLElement).closest('a, button') || justZoomed()) return;
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
		<button class="glass sound" class:shift={!!ondelete} onclick={() => (muted = !muted)} aria-label={muted ? 'Ligar o som' : 'Desligar o som'}>
			<Icon name={muted ? 'mute' : 'sound'} size={20} />
		</button>
	{:else if m.image}
		<div class="zoom" use:pinchZoom><img src={m.image} alt={m.caption || `Foto de ${person?.name ?? ''}`} loading="lazy" draggable="false" /></div>
	{/if}

	{#key bigHeart}
		{#if bigHeart}<span class="big-heart" aria-hidden="true"><Icon name="heart" size={96} stroke={1.5} /></span>{/if}
	{/key}

	{#if ondelete}
		<button class="glass trash" onclick={ondelete} aria-label="Apagar"><Icon name="trash" size={20} /></button>
	{/if}

	<!-- actions: frosted round buttons with a label, like the stories apps -->
	<div class="rail">
		<div class="act">
			<span class="glass like" class:on={likers.includes(meId)}><LikeButton bind:this={likeBtn} target={{ mediaId: m.id }} {likers} {meId} size={26} onchange={(l) => (likers = l)} /></span>
			<span class="lbl">{likers.length || 'Curtir'}</span>
		</div>
		<div class="act">
			<a class="glass" href="/m/{m.id}#comentarios" aria-label="Comentários"><Icon name="chat" size={24} /></a>
			<span class="lbl">{m.comments || 'Comentar'}</span>
		</div>
		<div class="act">
			<span class="glass fav" class:on={favs.includes(meId)}><FavButton mediaId={m.id} {favs} {meId} size={25} onchange={(f) => (favs = f)} /></span>
			<span class="lbl">{favs.length > 1 ? favs.length : 'Favorito'}</span>
		</div>
		{#if onshare}
			<div class="act">
				<button class="glass" onclick={onshare} aria-label="Compartilhar com moldura"><Icon name="frame" size={24} /></button>
				<span class="lbl">Moldura</span>
			</div>
		{/if}
		<div class="act">
			<a class="glass" href="/api/media/{m.id}/original" download aria-label="Salvar original"><Icon name="download" size={24} /></a>
			<span class="lbl">Salvar</span>
		</div>
	</div>

	<div class="info">
		<a class="who" href="/m/{m.id}" aria-label="Abrir detalhes">
			<Avatar name={person?.name ?? '?'} color={person?.color ?? '#888'} photo={person?.photo} size={36} />
			<strong>{person?.name ?? 'Alguém'}</strong>
			<span class="when">{fmtDayMonth(m.at)} · {fmtTime(m.at)}</span>
		</a>
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
	.zoom { width: 100%; height: 100%; }
	.play { position: absolute; color: #fff; opacity: 0.85; pointer-events: none; filter: drop-shadow(0 2px 8px rgb(0 0 0 / 0.5)); }
	.play :global(svg) { fill: #fff; }
	.sound.shift { right: 64px; }
	.sound { position: absolute; top: calc(12px + env(safe-area-inset-top)); right: 12px; width: 44px; height: 44px; }
	.big-heart { position: absolute; left: 50%; top: 50%; translate: -50% -50%; color: #fff; pointer-events: none; filter: drop-shadow(0 4px 12px rgb(0 0 0 / 0.4)); animation: big-heart 0.9s ease-out forwards; }
	.big-heart :global(svg) { fill: #fff; }
	@keyframes big-heart {
		0% { transform: scale(0); opacity: 0; }
		15% { transform: scale(1.2); opacity: 1; }
		30% { transform: scale(0.95); }
		45%, 75% { transform: scale(1); opacity: 1; }
		100% { transform: scale(1.1) translateY(-30px); opacity: 0; }
	}
	/* one look for every reel button: a dark frosted circle with a thin light ring */
	.glass {
		display: grid; place-items: center; width: 48px; height: 48px; border-radius: 50%; color: #fff; cursor: pointer;
		background: rgb(20 24 36 / 0.42); border: 1.5px solid rgb(255 255 255 / 0.22);
		-webkit-backdrop-filter: blur(10px) saturate(1.4); backdrop-filter: blur(10px) saturate(1.4);
		box-shadow: 0 4px 14px rgb(0 0 0 / 0.28); transition: transform 0.15s, background 0.2s;
	}
	.glass:active { transform: scale(0.9); }
	.glass :global(.like), .glass :global(.fav) { color: #fff; min-width: 46px; min-height: 46px; }
	.glass.like.on { background: rgb(214 76 110 / 0.3); border-color: rgb(255 140 170 / 0.55); }
	.glass.like.on :global(.like) { color: #ff6f91; }
	.glass.fav.on { background: rgb(240 190 70 / 0.28); border-color: rgb(255 214 110 / 0.6); }
	.glass.fav.on :global(.fav) { color: #ffd166; }
	.rail { position: absolute; right: 10px; bottom: 28px; display: grid; justify-items: center; gap: 12px; color: #fff; }
	.act { display: grid; justify-items: center; gap: 3px; }
	.lbl { font-size: 0.7rem; font-weight: 800; letter-spacing: 0.01em; text-shadow: 0 1px 3px rgb(0 0 0 / 0.8); }
	.trash { position: absolute; top: calc(12px + env(safe-area-inset-top)); right: 12px; width: 44px; height: 44px; }
	.trash:hover { background: rgb(190 50 50 / 0.55); }
	.info {
		position: absolute; left: 0; right: 72px; bottom: 0; padding: 48px 14px 18px; display: grid; gap: 6px; color: #fff;
		background: linear-gradient(transparent, rgb(0 0 0 / 0.65)); pointer-events: none;
	}
	.info a { pointer-events: auto; }
	.who { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; width: fit-content; color: #fff; text-decoration: none; }
	.who strong { font: 600 1.05rem var(--font-display); }
	.when { font-size: 0.8rem; opacity: 0.85; }
	.caption { margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; display: -webkit-box; -webkit-line-clamp: 3; line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
	.place { display: inline-flex; align-items: center; gap: 3px; width: fit-content; color: #fff; font-weight: 800; font-size: 0.85rem; text-decoration: none; }
</style>
