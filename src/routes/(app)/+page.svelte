<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { onMount } from 'svelte';
	import Avatar from '$lib/components/Avatar.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import Filters from '$lib/components/Filters.svelte';
	import LikeButton from '$lib/components/LikeButton.svelte';
	import LikedBy from '$lib/components/LikedBy.svelte';
	import Post from '$lib/components/Post.svelte';
	import { dayKey, fmtLongDay, fmtTime } from '$lib/format';
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

	// check-in likes live here (media likes live inside each Post)
	let checkinLikes = $state<Record<string, string[]>>({});
	$effect(() => {
		checkinLikes = Object.fromEntries(data.items.filter((i) => i.type === 'checkin').map((c) => [c.id, c.likers]));
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
						{@const c = e.item}
						{@const p = byId.get(c.userId)}
						<article class="card checkin">
							<header class="head">
								<Avatar name={p?.name ?? '?'} color={p?.color ?? '#888'} photo={p?.photo} size={40} />
								<div class="who">
									<strong>{p?.name ?? 'Alguém'}</strong>
									<span class="small muted">fez check-in · {fmtTime(c.at)}</span>
								</div>
							</header>
							<a class="banner" href="/mapa?foco={c.lat},{c.lng}" style:--c={p?.color}>
								<span class="pin"><Icon name="pin" size={34} stroke={2} /></span>
								{#if c.note}<span class="note">{c.note}</span>{:else}<span class="note muted-note">Esteve aqui</span>{/if}
								<span class="go small">Ver no mapa ›</span>
							</a>
							<div class="actions">
								<LikeButton target={{ checkinId: c.id }} likers={checkinLikes[c.id] ?? []} meId={data.me.id} onchange={(l) => (checkinLikes[c.id] = l)} />
								<a class="act" href="/c/{c.id}" aria-label="Comentários"><Icon name="chat" size={26} /></a>
							</div>
							<div class="text">
								<LikedBy likers={checkinLikes[c.id] ?? []} persons={byId} meId={data.me.id} />
								{#if c.comments}<a class="small muted more" href="/c/{c.id}">Ver {c.comments === 1 ? '1 comentário' : `os ${c.comments} comentários`}</a>{/if}
							</div>
						</article>
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
	.checkin { padding: 0; overflow: hidden; animation: pop-in 0.45s var(--bounce) both; }
	.head { display: flex; align-items: center; gap: 10px; padding: 10px 12px; }
	.who { display: grid; line-height: 1.25; }
	.who strong { font: 600 1.05rem var(--font-display); }
	.banner {
		display: grid; justify-items: center; gap: 8px; padding: 30px 20px; text-align: center; text-decoration: none; color: #fff;
		background: var(--sea); border-top: 2.5px solid var(--line); border-bottom: 2.5px solid var(--line);
		background-image: radial-gradient(rgb(255 255 255 / 0.18) 2px, transparent 2.5px); background-size: 18px 18px;
	}
	.pin { display: grid; place-items: center; width: 64px; height: 64px; border-radius: 50%; background: var(--c, var(--coral)); border: 4px solid #fff; box-shadow: 0 4px 0 rgb(0 0 0 / 0.2); animation: bob 2.6s ease-in-out infinite; }
	.note { font: 600 1.25rem/1.3 var(--font-display); max-width: 28ch; overflow-wrap: anywhere; white-space: pre-wrap; text-shadow: 0 1px 0 rgb(0 0 0 / 0.2); }
	.muted-note { opacity: 0.9; }
	.go { font-weight: 800; opacity: 0.95; }
	.actions { display: flex; align-items: center; gap: 2px; padding: 4px 6px 0; }
	.act { display: grid; place-items: center; min-width: 44px; min-height: 44px; color: var(--ink); }
	.text { display: grid; gap: 4px; padding: 0 14px 14px; }
	.more { text-decoration: none; font-weight: 700; }
</style>
