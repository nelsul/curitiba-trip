<script lang="ts">
	import { invalidate } from '$app/navigation';
	import Avatar from './Avatar.svelte';
	import Icon from './Icon.svelte';
	import LikeButton from './LikeButton.svelte';
	import LikedBy from './LikedBy.svelte';
	import { fmtTime } from '$lib/format';
	import type { FeedCheckin, Person } from '$lib/types';

	let {
		c,
		persons,
		meId,
		snapshot = null
	}: { c: FeedCheckin; persons: Map<string, Person>; meId: string; snapshot?: string | null } = $props();

	const p = $derived(persons.get(c.userId));
	const mine = $derived(c.userId === meId);
	let likers = $state<string[]>([]);
	$effect(() => {
		likers = c.likers;
	});

	let menuOpen = $state(false);
	let deleting = $state(false);
	let gone = $state(false);
	let error = $state('');

	async function remove() {
		menuOpen = false;
		if (!confirm('Apagar este check-in? Os comentários e curtidas dele também somem.')) return;
		deleting = true;
		error = '';
		try {
			const r = await fetch(`/api/checkins/${c.id}`, { method: 'DELETE' });
			if (!r.ok) throw new Error((await r.json().catch(() => null))?.message ?? 'Não foi possível apagar.');
			gone = true; // play the exit animation, then refresh
			setTimeout(() => invalidate('app:feed'), 380);
		} catch (e) {
			error = (e as Error).message;
			deleting = false;
		}
	}

	const pic = $derived(snapshot ?? c.snapshot);
</script>

<svelte:window onclick={() => (menuOpen = false)} />

<article class="card checkin" class:gone aria-busy={deleting}>
	<header class="head">
		<Avatar name={p?.name ?? '?'} color={p?.color ?? '#888'} photo={p?.photo} size={40} />
		<div class="who">
			<strong>{p?.name ?? 'Alguém'}</strong>
			<span class="small muted">fez check-in · {fmtTime(c.at)}</span>
		</div>
		{#if mine}
			<div class="menu-wrap">
				<button class="more-btn" aria-label="Opções do check-in" aria-expanded={menuOpen} onclick={(e) => { e.stopPropagation(); menuOpen = !menuOpen; }}>⋯</button>
				{#if menuOpen}
					<div class="menu card" role="menu">
						<a role="menuitem" href="/c/{c.id}">Editar texto</a>
						<button role="menuitem" class="danger" onclick={remove} disabled={deleting}>Apagar check-in</button>
					</div>
				{/if}
			</div>
		{/if}
	</header>

	<a class="visual" href="/mapa?foco={c.lat},{c.lng}" aria-label="Ver o check-in de {p?.name} no mapa">
		{#if pic}
			<img src={pic} alt="Mapa do check-in de {p?.name ?? ''}" loading="lazy" width="1080" height="720" />
		{:else}
			<span class="banner" style:--c={p?.color}>
				<span class="pin"><Icon name="pin" size={34} stroke={2} /></span>
				<span class="go small">Ver no mapa ›</span>
			</span>
		{/if}
	</a>

	<div class="actions">
		<LikeButton target={{ checkinId: c.id }} {likers} {meId} onchange={(l) => (likers = l)} />
		<a class="act" href="/c/{c.id}" aria-label="Comentários"><Icon name="chat" size={26} /></a>
		<a class="act" href="/mapa?foco={c.lat},{c.lng}" aria-label="Ver no mapa"><Icon name="map" size={24} /></a>
	</div>

	<div class="text">
		<LikedBy {likers} {persons} {meId} />
		{#if c.note}<p class="caption"><strong>{p?.name}</strong> {c.note}</p>{/if}
		{#if c.comments}<a class="small muted more" href="/c/{c.id}">Ver {c.comments === 1 ? '1 comentário' : `os ${c.comments} comentários`}</a>{/if}
		{#if error}<p class="error small" role="alert">{error}</p>{/if}
	</div>
</article>

<style>
	.checkin { padding: 0; overflow: visible; animation: pop-in 0.45s var(--bounce) both; transition: transform 0.35s ease-in, opacity 0.35s ease-in; }
	.checkin.gone { transform: scale(0.85) rotate(-3deg); opacity: 0; }
	.checkin[aria-busy='true'] { opacity: 0.6; }
	.head { display: flex; align-items: center; gap: 10px; padding: 10px 12px; }
	.who { display: grid; line-height: 1.25; }
	.who strong { font: 600 1.05rem var(--font-display); }
	.menu-wrap { position: relative; margin-left: auto; }
	.more-btn { min-width: 44px; min-height: 44px; border: 0; background: none; color: var(--ink); font-size: 1.6rem; line-height: 1; cursor: pointer; border-radius: 12px; }
	.more-btn:hover { background: var(--surface-2); }
	.menu { position: absolute; right: 0; top: 46px; z-index: 10; display: grid; padding: 6px; min-width: 180px; animation: pop-in 0.25s var(--bounce); }
	.menu a, .menu button { display: block; text-align: left; padding: 10px 12px; border-radius: 10px; border: 0; background: none; font: inherit; font-weight: 800; color: var(--ink); text-decoration: none; cursor: pointer; }
	.menu a:hover, .menu button:hover { background: var(--surface-2); }
	.menu .danger { color: var(--danger); }
	.visual { display: block; border-top: 2.5px solid var(--line); border-bottom: 2.5px solid var(--line); background: var(--sea-light); }
	.visual img { width: 100%; height: auto; aspect-ratio: 3 / 2; object-fit: cover; }
	.banner {
		display: grid; justify-items: center; align-content: center; gap: 10px; aspect-ratio: 3 / 2; color: #fff; text-decoration: none;
		background: var(--sea); background-image: radial-gradient(rgb(255 255 255 / 0.18) 2px, transparent 2.5px); background-size: 18px 18px;
	}
	.pin { display: grid; place-items: center; width: 64px; height: 64px; border-radius: 50%; background: var(--c, var(--coral)); border: 4px solid #fff; box-shadow: 0 4px 0 rgb(0 0 0 / 0.2); animation: bob 2.6s ease-in-out infinite; }
	.go { font-weight: 800; }
	.actions { display: flex; align-items: center; gap: 2px; padding: 4px 6px 0; }
	.act { display: grid; place-items: center; min-width: 44px; min-height: 44px; color: var(--ink); }
	.text { display: grid; gap: 4px; padding: 0 14px 14px; }
	.caption { margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; }
	.caption strong { font-weight: 800; margin-right: 4px; }
	.more { text-decoration: none; font-weight: 700; }
	.error { margin: 0; }
</style>
