<script lang="ts">
	import { enhance } from '$app/forms';
	import Avatar from '$lib/components/Avatar.svelte';
	import Comments from '$lib/components/Comments.svelte';
	import LocationPicker from '$lib/components/LocationPicker.svelte';
	import LikeButton from '$lib/components/LikeButton.svelte';
	import LikedBy from '$lib/components/LikedBy.svelte';
	import { dayKey, fmtLongDay, fmtTime } from '$lib/format';

	let { data, form } = $props();
	const it = $derived(data.item);
	const mine = $derived(it.userId === data.me.id);
	const personMap = $derived(new Map(data.persons.map((p) => [p.id, p])));
	let likers = $state<string[]>([]);
	$effect(() => {
		likers = data.likers;
	});
	let editing = $state(false);
	let note = $state('');
</script>

<svelte:head><title>Check-in de {it.name} · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<a href="/" class="back btn small secondary">← Diário</a>
	<header class="who">
		<Avatar name={it.name} color={it.color} photo={it.photo} size={44} />
		<div>
			<strong>{it.name}</strong> fez check-in
			<p class="small muted"><span class="cap">{fmtLongDay(dayKey(it.at))}</span>, {fmtTime(it.at)}</p>
		</div>
	</header>

	{#if editing}
		<form method="POST" action="?/nota" use:enhance={() => async ({ update }) => { await update({ reset: false }); editing = false; }} class="stack">
			<textarea name="note" bind:value={note} rows="3"></textarea>
			<div class="row"><button type="button" class="btn secondary small" onclick={() => (editing = false)}>Cancelar</button><button class="btn small">Salvar</button></div>
		</form>
	{:else}
		{#if it.note}<p class="caption">{it.note}</p>{/if}
		{#if mine}<button class="link" onclick={() => { note = it.note; editing = true; }}>{it.note ? 'Editar texto' : 'Adicionar texto'}</button>{/if}
	{/if}

	<div class="like-row">
		<LikeButton target={{ checkinId: it.id }} {likers} meId={data.me.id} onchange={(l) => (likers = l)} />
		<LikedBy {likers} persons={personMap} meId={data.me.id} />
	</div>

	<div class="map"><LocationPicker lat={it.lat} lng={it.lng} color={it.color} /></div>
	<p class="small"><a href="/mapa?foco={it.lat},{it.lng}">Ver no mapa da viagem</a> · <a href="https://www.google.com/maps/search/?api=1&query={it.lat},{it.lng}" target="_blank" rel="noopener">Google Maps</a></p>

	{#if mine}
		<form method="POST" action="?/apagar" use:enhance={({ cancel }) => { if (!confirm('Apagar este check-in?')) cancel(); }}>
			<button class="btn small danger">Apagar check-in</button>
		</form>
	{/if}

	<Comments comments={data.comments} meId={data.me.id} error={form?.commentError} />
</main>

<style>
	.back { margin-bottom: 8px; }
	.who { display: flex; gap: 10px; align-items: center; margin: 8px 0; }
	.who p { margin: 0; }
	.cap { display: inline-block; }
	.cap::first-letter { text-transform: uppercase; }
	.caption { position: relative; white-space: pre-wrap; overflow-wrap: anywhere; font-size: 1.05rem; margin: 14px 0 4px; background: var(--surface); border: 2.5px solid var(--line); border-radius: 18px; padding: 10px 14px; box-shadow: 0 3px 0 var(--shadow); }
	.link { background: none; border: 0; padding: 0; color: var(--pine); text-decoration: underline; cursor: pointer; min-height: 36px; }
	.map { margin-top: 12px; }
	.like-row { display: flex; align-items: center; gap: 4px; margin: 6px 0 0 -8px; }
	.stack { display: grid; gap: 8px; }
	.row { display: flex; gap: 8px; justify-content: flex-end; }
</style>
