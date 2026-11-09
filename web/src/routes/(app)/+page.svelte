<script lang="ts">
	import { invalidate, pushState } from '$app/navigation';
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import Icon from '$lib/components/Icon.svelte';
	import Filters from '$lib/components/Filters.svelte';
	import CheckinPost from '$lib/components/CheckinPost.svelte';
	import Post from '$lib/components/Post.svelte';
	import Countdown from '$lib/components/Countdown.svelte';
	import MediaGrid from '$lib/components/MediaGrid.svelte';
	import ReelsViewer from '$lib/components/ReelsViewer.svelte';
	import FrameMaker from '$lib/components/FrameMaker.svelte';
	import { dayKey, fmtLongDay } from '$lib/format';
	import { FRAME_MAX } from '$lib/frames';
	import { TRIP_DAYS } from '$lib/trip';
	import type { FeedCheckin, FeedItem, FeedMedia } from '$lib/types';
	import { groupPosts, type Post as FeedPost } from '$lib/feed-group';

	let { data } = $props();

	const today = dayKey(Date.now());
	let day = $state(TRIP_DAYS.includes(today) ? today : 'all');
	let person = $state('all');
	/** Diário (posts) or Fotos (the grid of every photo and video) */
	let mode = $state<'diario' | 'grade'>(page.url.searchParams.get('modo') === 'grade' ? 'grade' : 'diario');

	const byId = $derived(new Map(data.persons.map((p) => [p.id, p])));
	const days = $derived([...new Set([...TRIP_DAYS, ...data.items.map((i) => i.day)])].sort());

	const filtered = $derived(
		data.items.filter((i: FeedItem) => (day === 'all' || i.day === day) && (person === 'all' || i.userId === person))
	);
	/** Day → posts, newest first (grouping shared with GET /api/feed, see $lib/feed-group). */
	const grouped = $derived.by(() => {
		const out = new Map<string, FeedPost[]>();
		for (const p of groupPosts(filtered)) (out.get(p.day) ?? out.set(p.day, []).get(p.day)!).push(p);
		return [...out.entries()];
	});
	/** every ready photo/video with the current filters, newest first: the grid and the reels */
	const media = $derived(
		filtered
			.filter((i): i is FeedMedia => i.type === 'media' && i.status === 'ready' && !!(i.image || i.video))
			.sort((a, b) => b.at.localeCompare(a.at))
	);

	// ── reels (shallow route, so the phone's back button closes them) ──
	const reel = $derived((page.state as { reel?: string }).reel ?? null);
	const openReel = (id: string) => pushState('', { reel: id });
	const closeReel = () => history.back();

	// ── grid selection → frame ──
	let selecting = $state(false);
	let selected = $state<string[]>([]);
	let framing = $state<string[] | null>(null);
	let retroMsg = $state('');

	async function addToRetro() {
		const r = await fetch('/api/retro').then((r) => r.json());
		const ids = [...r.items.map((i: FeedMedia) => i.id), ...selected.filter((id) => !r.items.some((i: FeedMedia) => i.id === id))];
		const res = await fetch('/api/admin/retro', { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ mediaIds: ids }) });
		retroMsg = res.ok ? `${selected.length} na retrospectiva (${ids.length} no total).` : 'Não foi possível salvar.';
		setTimeout(() => (retroMsg = ''), 3000);
		if (res.ok) {
			selecting = false;
			selected = [];
		}
	}

	async function remove(id: string) {
		if (!confirm('Apagar esta foto/vídeo para todo mundo? Não dá para desfazer.')) return;
		const r = await fetch(`/api/media/${id}`, { method: 'DELETE' });
		if (!r.ok) return alert((await r.json().catch(() => null))?.message ?? 'Não foi possível apagar.');
		const next = media[media.findIndex((m) => m.id === id) + 1]?.id;
		await invalidate('app:feed');
		if (!next) closeReel();
	}

	// Check-ins made before map pictures existed (or whose picture failed) get one the first time
	// someone sees them: generated in this browser, one at a time, then shared with everyone.
	let snaps = $state<Record<string, string | null>>({});
	const tried = new Set<string>();
	let backfilling = false;
	$effect(() => {
		const missing = data.items.filter((i): i is FeedCheckin => i.type === 'checkin' && !i.snapshot && !tried.has(i.id));
		if (!missing.length || backfilling) return;
		backfilling = true;
		(async () => {
			const { attachSnapshot } = await import('$lib/map-snapshot');
			for (const c of missing) {
				tried.add(c.id);
				const p = byId.get(c.userId);
				const url = await attachSnapshot(c.id, { lat: c.lat, lng: c.lng, color: p?.color ?? '#2F5A40', name: p?.name ?? '?', photo: p?.photo, at: c.at });
				if (url) snaps[c.id] = url;
			}
			backfilling = false;
		})();
	});

	const processing = $derived(data.items.some((i) => i.type === 'media' && i.status === 'processing'));

	onMount(() => {
		const t = setInterval(() => {
			if (document.visibilityState === 'visible' && !reel) invalidate('app:feed');
		}, processing ? 8000 : 60_000);
		return () => clearInterval(t);
	});
</script>

<svelte:head><title>Diário · Viagem a Curitiba</title></svelte:head>

<main class="page feed" class:selecting>
	<div class="title-row"><span class="title-icon"><Icon name="journal" size={26} /></span><h1>Diário da viagem</h1></div>
	<Countdown />

	<div class="modes" role="tablist" aria-label="Ver">
		<button role="tab" aria-selected={mode === 'diario'} onclick={() => { mode = 'diario'; selecting = false; }}><Icon name="journal" size={18} /> Diário</button>
		<button role="tab" aria-selected={mode === 'grade'} onclick={() => (mode = 'grade')}><Icon name="grid" size={18} /> Todas as fotos</button>
	</div>
	<Filters {days} persons={data.persons} bind:day bind:person />

	{#if mode === 'grade'}
		<div class="grid-bar">
			<span class="small muted">{media.length} {media.length === 1 ? 'item' : 'itens'}</span>
			<button class="btn small" class:secondary={selecting} onclick={() => { selecting = !selecting; selected = []; }}>
				{selecting ? 'Cancelar' : 'Selecionar'}
			</button>
		</div>
		{#if selecting}<p class="small muted hint">Escolha até {FRAME_MAX} fotos para juntar numa imagem com moldura.</p>{/if}
		<MediaGrid media={selecting ? media.filter((m) => m.kind === 'photo' || data.me.isAdmin) : media} {selecting} bind:selected max={data.me.isAdmin ? 300 : FRAME_MAX} onopen={openReel} />
		{#if retroMsg}<p class="toast" role="status">{retroMsg}</p>{/if}
		{#if selecting && selected.length}
			<div class="select-bar card">
				<strong>{selected.length} {selected.length === 1 ? 'escolhida' : 'escolhidas'}</strong>
				{#if data.me.isAdmin}<button class="btn small secondary" onclick={addToRetro}><Icon name="sparkle" size={16} /> Retrospectiva</button>{/if}
				<button class="btn small sun" onclick={() => (framing = [...selected])}
					disabled={selected.length > FRAME_MAX || selected.some((id) => media.find((m) => m.id === id)?.kind !== 'photo')}>
					<Icon name="frame" size={16} /> Moldura
				</button>
			</div>
		{/if}
	{:else}
		{#if grouped.length === 0}
			<div class="card empty">
				<span class="empty-art"><Icon name="island" size={56} stroke={1.8} /></span>
				<p>Nada por aqui ainda{day !== 'all' ? ' neste dia' : ''}. Que tal registrar o primeiro momento?</p>
				<a class="btn sun" href="/enviar">Enviar fotos e vídeos</a>
			</div>
		{/if}

		{#each grouped as [d, entries] (d)}
			<section class="day">
				<h2 class="day-title">{fmtLongDay(d)}</h2>
				<div class="posts">
					{#each entries as e (e.key)}
						{#if e.type === 'media'}
							<Post items={e.items} persons={byId} meId={data.me.id} onopen={openReel} />
						{:else}
							<CheckinPost c={e.item} persons={byId} meId={data.me.id} isAdmin={data.me.isAdmin} snapshot={snaps[e.item.id]} />
						{/if}
					{/each}
				</div>
			</section>
		{/each}
	{/if}
</main>

{#if reel}
	<ReelsViewer {media} start={reel} persons={byId} meId={data.me.id} isAdmin={data.me.isAdmin} onclose={closeReel}
		onshare={(id) => (framing = [id])} ondelete={remove} />
{/if}
{#if framing}<FrameMaker ids={framing} onclose={() => (framing = null)} />{/if}

<style>
	.feed { max-width: 600px; }
	.feed.selecting { padding-bottom: 180px; }
	.modes { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-bottom: 10px; padding: 4px; background: var(--surface); border: 2.5px solid var(--line); border-radius: 999px; }
	.modes button { display: inline-flex; align-items: center; justify-content: center; gap: 6px; min-height: 40px; border: 0; border-radius: 999px; background: none; color: var(--muted); font: 600 1rem var(--font-display); cursor: pointer; }
	.modes button[aria-selected='true'] { background: var(--sea); color: var(--on-sea); }
	.grid-bar { display: flex; align-items: center; justify-content: space-between; margin: 4px 0 8px; }
	.hint { margin: 0 0 8px; }
	.select-bar {
		position: fixed; z-index: 25; left: 12px; right: 12px; bottom: calc(var(--nav-h) + 16px + env(safe-area-inset-bottom)); max-width: 560px; margin: 0 auto;
		display: flex; align-items: center; gap: 8px; padding: 10px 12px; animation: pop-in 0.3s var(--bounce);
	}
	.select-bar strong { margin-right: auto; }
	.toast { position: fixed; z-index: 26; left: 50%; translate: -50% 0; bottom: calc(var(--nav-h) + 84px); background: var(--leaf); color: var(--on-leaf); font-weight: 800; padding: 8px 16px; border-radius: 999px; }
	.empty { display: grid; gap: 12px; justify-items: center; text-align: center; padding: 28px 16px; }
	.empty p { margin: 0; max-width: 32ch; }
	.empty-art { color: var(--sea); animation: bob 3s ease-in-out infinite; }
	.day { margin-bottom: 28px; }
	.day-title {
		position: sticky; top: calc(64px + env(safe-area-inset-top)); z-index: 5; display: block; width: fit-content; margin: 0 auto 14px;
		font-size: 1.15rem; padding: 6px 22px; color: #fff8e6;
		background: linear-gradient(#b07a4a, #9a6638); border-radius: 12px; box-shadow: 0 4px 0 #6e4626;
		border: 2.5px solid #7e522c; text-shadow: 0 1px 0 #6e4626;
	}
	.day-title::first-letter { text-transform: uppercase; }
	.posts { display: grid; gap: 22px; }
	@media (max-width: 520px) {
		/* edge-to-edge posts and grid on phones, like Instagram */
		.posts, .feed :global(.grid) { margin: 0 -16px; }
		.posts > :global(.card) { border-radius: 0; border-left: 0; border-right: 0; }
	}
</style>
