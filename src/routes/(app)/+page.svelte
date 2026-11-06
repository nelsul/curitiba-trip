<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { onMount } from 'svelte';
	import Avatar from '$lib/components/Avatar.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import Filters from '$lib/components/Filters.svelte';
	import { dayKey, fmtDuration, fmtLongDay, fmtTime } from '$lib/format';
	import { TRIP_DAYS } from '$lib/trip';
	import type { FeedCheckin, FeedItem, FeedMedia } from '$lib/types';

	let { data } = $props();

	const today = dayKey(Date.now());
	let day = $state(TRIP_DAYS.includes(today) ? today : 'all');
	let person = $state('all');

	const byId = $derived(new Map(data.persons.map((p) => [p.id, p])));
	const days = $derived([...new Set([...TRIP_DAYS, ...data.items.map((i) => i.day)])].sort());

	type Entry =
		| { type: 'media'; key: string; userId: string; from: string; to: string; items: FeedMedia[] }
		| { type: 'checkin'; key: string; userId: string; item: FeedCheckin };

	const GROUP_GAP = 30 * 60_000;

	/** Day → entries; consecutive media from the same person within 30 min become one entry. */
	const grouped = $derived.by(() => {
		const filtered = data.items.filter(
			(i: FeedItem) => (day === 'all' || i.day === day) && (person === 'all' || i.userId === person)
		);
		const out = new Map<string, Entry[]>();
		for (const it of filtered) {
			const list = out.get(it.day) ?? out.set(it.day, []).get(it.day)!;
			if (it.type === 'checkin') {
				list.push({ type: 'checkin', key: `c${it.id}`, userId: it.userId, item: it });
				continue;
			}
			const last = list.at(-1);
			if (last?.type === 'media' && last.userId === it.userId && Date.parse(it.at) - Date.parse(last.to) <= GROUP_GAP) {
				last.items.push(it);
				last.to = it.at;
			} else {
				list.push({ type: 'media', key: `m${it.id}`, userId: it.userId, from: it.at, to: it.at, items: [it] });
			}
		}
		return [...out.entries()];
	});

	const processing = $derived(data.items.some((i) => i.type === 'media' && i.status === 'processing'));

	onMount(() => {
		const t = setInterval(() => {
			if (document.visibilityState === 'visible') invalidate('app:feed');
		}, processing ? 8000 : 60_000);
		return () => clearInterval(t);
	});
</script>

<svelte:head><title>Linha do tempo · Viagem a Curitiba</title></svelte:head>

<main class="page">
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
			<ol class="timeline">
				{#each entries as e, i (e.key)}
					{@const p = byId.get(e.userId)}
					<li class="entry" style:animation-delay="{Math.min(i, 8) * 50}ms">
						<div class="when">
							{#if e.type === 'media'}{fmtTime(e.from)}{:else}{fmtTime(e.item.at)}{/if}
						</div>
						<div class="dot" style:background={p?.color} aria-hidden="true"></div>
						<div class="body card bubble">
							<header class="who">
								<Avatar name={p?.name ?? '?'} color={p?.color ?? '#888'} photo={p?.photo} size={32} />
								<strong>{p?.name ?? 'Alguém'}</strong>
								<span class="muted small">
									{#if e.type === 'media'}
										{e.items.length === 1 ? (e.items[0].kind === 'video' ? 'enviou um vídeo' : 'enviou uma foto') : `enviou ${e.items.length} itens`}
										{#if e.from !== e.to} · até {fmtTime(e.to)}{/if}
									{:else}
										fez check-in
									{/if}
								</span>
							</header>

							{#if e.type === 'media'}
								<div class="grid" class:single={e.items.length === 1}>
									{#each e.items as m, j (m.id)}
										<a class="tile" style:--tilt="{e.items.length === 1 ? -1.5 : [-2, 1.5, -1, 2, -1.5][j % 5]}deg" href="/m/{m.id}" aria-label="{m.kind === 'video' ? 'Vídeo' : 'Foto'} de {p?.name}, {fmtTime(m.at)}">
											{#if m.thumb}
												<img src={m.thumb} alt="" loading="lazy" />
											{:else}
												<span class="ph">{m.status === 'failed' ? 'Falhou' : 'Processando…'}</span>
											{/if}
											{#if m.kind === 'video'}<span class="badge"><Icon name="play" size={11} stroke={3} /> {m.durationS ? fmtDuration(m.durationS) : ''}</span>{/if}
											{#if m.comments}<span class="badge right"><Icon name="chat" size={11} stroke={3} /> {m.comments}</span>{/if}
										</a>
									{/each}
								</div>
								{#each e.items.filter((m) => m.caption) as m (m.id)}
									<p class="caption">{m.caption}</p>
								{/each}
							{:else}
								{#if e.item.note}<p class="caption">{e.item.note}</p>{/if}
								<p class="small links">
									<a href="/mapa?foco={e.item.lat},{e.item.lng}"><Icon name="pin" size={18} /> Ver no mapa</a>
									<a href="/c/{e.item.id}"><Icon name="chat" size={18} /> {e.item.comments ? `${e.item.comments} comentário${e.item.comments > 1 ? 's' : ''}` : 'Comentar'}</a>
								</p>
							{/if}
						</div>
					</li>
				{/each}
			</ol>
		</section>
	{/each}
</main>

<style>
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
	.timeline { list-style: none; margin: 0; padding: 0; display: grid; gap: 14px; }
	.entry { display: grid; grid-template-columns: 50px 16px 1fr; gap: 10px; position: relative; animation: pop-in 0.45s var(--bounce) both; }
	.entry::before {
		content: ''; position: absolute; left: 66px; top: 30px; bottom: -14px; width: 0;
		border-left: 4px dotted var(--line);
	}
	.entry:last-child::before { display: none; }
	.when {
		align-self: start; margin-top: 12px; font-family: var(--font-display); font-weight: 600; font-size: 0.8rem; text-align: center;
		background: var(--sun); color: #4a3410; border-radius: 10px; padding: 2px 0; box-shadow: 0 2px 0 var(--sun-dark);
	}
	.dot { width: 16px; height: 16px; border-radius: 50%; margin-top: 16px; position: relative; z-index: 1; border: 3px solid var(--surface); box-shadow: 0 0 0 2px var(--line); }
	.body { padding: 12px 14px; min-width: 0; }
	.who { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin-bottom: 10px; }
	.who strong { font-family: var(--font-display); font-weight: 600; font-size: 1.05rem; }
	.grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; padding: 4px; }
	.grid.single { grid-template-columns: minmax(0, 340px); }
	@media (min-width: 700px) { .grid:not(.single) { grid-template-columns: repeat(5, 1fr); } }
	.tile {
		position: relative; aspect-ratio: 1; display: block; padding: 5px 5px 14px; background: #fff; border-radius: 6px;
		box-shadow: 0 3px 8px rgb(90 69 48 / 0.25); transform: rotate(var(--tilt, 0deg)); transition: transform 0.25s var(--bounce);
	}
	.tile:hover, .tile:focus-visible { transform: rotate(0deg) scale(1.04); z-index: 2; }
	.tile img { width: 100%; height: 100%; object-fit: cover; border-radius: 3px; background: var(--track); }
	.ph { position: absolute; inset: 5px 5px 14px; display: grid; place-items: center; font-size: 0.72rem; font-weight: 800; color: var(--muted); text-align: center; padding: 4px; background: var(--track); border-radius: 3px; }
	.badge { display: inline-flex; align-items: center; gap: 3px; position: absolute; left: 10px; bottom: 20px; background: rgb(40 30 20 / 0.7); color: #fff; font-size: 0.7rem; font-weight: 800; padding: 2px 7px; border-radius: 999px; }
	.badge.right { left: auto; right: 10px; }
	.caption { margin: 10px 0 0; white-space: pre-wrap; overflow-wrap: anywhere; }
	.links { display: flex; gap: 16px; margin: 8px 0 0; flex-wrap: wrap; }
	.links a { min-height: 32px; display: inline-flex; align-items: center; gap: 4px; }
</style>
