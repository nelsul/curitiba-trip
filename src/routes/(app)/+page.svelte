<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { onMount } from 'svelte';
	import Icon from '$lib/components/Icon.svelte';
	import Filters from '$lib/components/Filters.svelte';
	import CheckinPost from '$lib/components/CheckinPost.svelte';
	import Post from '$lib/components/Post.svelte';
	import { dayKey, fmtLongDay } from '$lib/format';
	import { TRIP_DAYS } from '$lib/trip';
	import type { FeedCheckin, FeedItem, FeedMedia } from '$lib/types';

	let { data } = $props();

	const today = dayKey(Date.now());
	let day = $state(TRIP_DAYS.includes(today) ? today : 'all');
	let person = $state('all');

	const byId = $derived(new Map(data.persons.map((p) => [p.id, p])));
	const days = $derived([...new Set([...TRIP_DAYS, ...data.items.map((i) => i.day)])].sort());

	type Entry =
		| { type: 'media'; key: string; userId: string; to: string; items: FeedMedia[] }
		| { type: 'checkin'; key: string; item: FeedCheckin };

	const GROUP_GAP = 30 * 60_000;

	/** Day → posts, newest first. Consecutive photos/videos from the same person within 30 min become one carousel post. */
	const grouped = $derived.by(() => {
		const filtered = data.items.filter(
			(i: FeedItem) => (day === 'all' || i.day === day) && (person === 'all' || i.userId === person)
		);
		const out = new Map<string, Entry[]>();
		for (const it of filtered) {
			const list = out.get(it.day) ?? out.set(it.day, []).get(it.day)!;
			if (it.type === 'checkin') {
				list.push({ type: 'checkin', key: `c${it.id}`, item: it });
				continue;
			}
			const last = list.at(-1);
			if (last?.type === 'media' && last.userId === it.userId && Date.parse(it.at) - Date.parse(last.to) <= GROUP_GAP) {
				last.items.push(it);
				last.to = it.at;
			} else {
				list.push({ type: 'media', key: `m${it.id}`, userId: it.userId, to: it.at, items: [it] });
			}
		}
		// newest first: latest day on top, latest post first within it (carousel photos keep their own order)
		return [...out.entries()].reverse().map(([d, list]) => [d, list.reverse()] as const);
	});

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
			if (document.visibilityState === 'visible') invalidate('app:feed');
		}, processing ? 8000 : 60_000);
		return () => clearInterval(t);
	});
</script>

<svelte:head><title>Diário · Viagem a Curitiba</title></svelte:head>

<main class="page feed">
	<div class="title-row"><span class="title-icon"><Icon name="journal" size={26} /></span><h1>Diário da viagem</h1></div>
	<Filters {days} persons={data.persons} bind:day bind:person />

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
						<Post items={e.items} persons={byId} meId={data.me.id} />
					{:else}
						<CheckinPost c={e.item} persons={byId} meId={data.me.id} snapshot={snaps[e.item.id]} />
					{/if}
				{/each}
			</div>
		</section>
	{/each}
</main>

<style>
	.feed { max-width: 600px; }
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
		/* edge-to-edge posts on phones, like Instagram */
		.posts { margin: 0 -16px; }
		.posts > :global(.card) { border-radius: 0; border-left: 0; border-right: 0; }
	}
</style>
