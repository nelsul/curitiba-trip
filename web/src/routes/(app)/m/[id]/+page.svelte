<script lang="ts">
	import { enhance } from '$app/forms';
	import { invalidate } from '$app/navigation';
	import { onMount } from 'svelte';
	import Avatar from '$lib/components/Avatar.svelte';
	import Comments from '$lib/components/Comments.svelte';
	import LocationPicker from '$lib/components/LocationPicker.svelte';
	import LikeButton from '$lib/components/LikeButton.svelte';
	import LikedBy from '$lib/components/LikedBy.svelte';
	import { fmtBytes, fmtTime, fmtDuration, fmtLongDay, dayKey } from '$lib/format';

	let { data, form } = $props();
	const it = $derived(data.item);
	const mine = $derived(it.userId === data.me.id);
	const personMap = $derived(new Map(data.persons.map((p) => [p.id, p])));
	let likers = $state<string[]>([]);
	$effect(() => {
		likers = data.likers;
	});

	let editCaption = $state(false);
	let caption = $state('');
	let editLoc = $state(false);
	let lat = $state<number | null>(null);
	let lng = $state<number | null>(null);

	const sourceLabel: Record<string, string> = { exif: 'da própria foto', device: 'do celular no envio', manual: 'marcado à mão' };

	onMount(() => {
		const t = setInterval(() => {
			if (it.status === 'processing') invalidate('app:media');
		}, 6000);
		return () => clearInterval(t);
	});
</script>

<svelte:head><title>{it.kind === 'video' ? 'Vídeo' : 'Foto'} de {it.name} · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<a href="/" class="back btn small secondary">← Diário</a>

	<figure class="viewer">
		{#if it.status === 'processing'}
			<div class="state">
				{#if it.poster}<img src={it.poster} alt="" />{/if}
				<p>Processando{it.kind === 'video' ? ' o vídeo (alguns minutos)' : ''}…</p>
			</div>
		{:else if it.status === 'failed'}
			<div class="state"><p>Não foi possível processar este arquivo. O original está salvo e pode ser baixado.</p></div>
		{:else if it.kind === 'video' && it.video}
			<!-- svelte-ignore a11y_media_has_caption -->
			<video src={it.video} poster={it.poster} controls playsinline preload="metadata" style:aspect-ratio={it.width && it.height ? `${it.width}/${it.height}` : undefined}></video>
		{:else if it.display}
			<a href={it.display} target="_blank" rel="noopener">
				<img src={it.display} alt={it.caption || `Foto de ${it.name}`} width={it.width} height={it.height} />
			</a>
		{/if}
	</figure>

	<div class="like-row">
		<LikeButton target={{ mediaId: it.id }} {likers} meId={data.me.id} onchange={(l) => (likers = l)} />
		<LikedBy {likers} persons={personMap} meId={data.me.id} />
	</div>

	<header class="who">
		<Avatar name={it.name} color={it.color} photo={it.photo} size={44} />
		<div>
			<strong>{it.name}</strong>
			<p class="small muted"><span class="cap">{fmtLongDay(dayKey(it.at))}</span>, {fmtTime(it.at)}{it.takenAtSource === 'upload' ? ' (hora do envio)' : ''}</p>
		</div>
	</header>

	{#if editCaption}
		<form method="POST" action="?/legenda" use:enhance={() => async ({ update }) => { await update({ reset: false }); editCaption = false; }} class="stack">
			<textarea name="caption" bind:value={caption} rows="3" placeholder="Escreva sobre este momento…"></textarea>
			<div class="row"><button type="button" class="btn secondary small" onclick={() => (editCaption = false)}>Cancelar</button><button class="btn small">Salvar</button></div>
		</form>
	{:else}
		{#if it.caption}<p class="caption">{it.caption}</p>{/if}
		{#if mine}<button class="link" onclick={() => { caption = it.caption; editCaption = true; }}>{it.caption ? 'Editar texto' : 'Adicionar texto'}</button>{/if}
	{/if}

	<section class="place">
		<h2>Onde</h2>
		{#if editLoc}
			<p class="small muted">Busque o lugar, toque no mapa ou arraste o marcador até o lugar certo.</p>
			<LocationPicker bind:lat bind:lng editable color={it.color} />
			<form method="POST" action="?/local" use:enhance={() => async ({ update }) => { await update(); editLoc = false; }} class="row">
				<input type="hidden" name="lat" value={lat} /><input type="hidden" name="lng" value={lng} />
				<button type="button" class="btn secondary small" onclick={() => (editLoc = false)}>Cancelar</button>
				<button class="btn small" disabled={lat == null}>Salvar local</button>
			</form>
			{#if form?.locError}<p class="error small">{form.locError}</p>{/if}
		{:else if it.lat != null && it.lng != null}
			{#key `${it.lat},${it.lng}`}<LocationPicker lat={it.lat} lng={it.lng} color={it.color} />{/key}
			<p class="small muted">Local {sourceLabel[it.locationSource ?? ''] ?? ''} · <a href="/mapa?foco={it.lat},{it.lng}">ver no mapa</a> · <a href="https://www.google.com/maps/search/?api=1&query={it.lat},{it.lng}" target="_blank" rel="noopener">Google Maps</a></p>
			{#if mine}<button class="link" onclick={() => { lat = it.lat; lng = it.lng; editLoc = true; }}>Corrigir local</button>{/if}
		{:else}
			<p class="muted">Sem local.</p>
			{#if mine}<button class="btn small secondary" onclick={() => { lat = null; lng = null; editLoc = true; }}>Marcar no mapa</button>{/if}
		{/if}
	</section>

	<section class="file small muted">
		<p>
			{it.originalName} · {fmtBytes(it.sizeBytes)}{#if it.width} · {it.width}×{it.height}{/if}{#if it.durationS} · {fmtDuration(it.durationS)}{/if}
		</p>
		<div class="row start">
			{#if it.original}<a class="btn small sea" href={it.original}>Baixar original</a>{/if}
			{#if mine}
				<form method="POST" action="?/apagar" use:enhance={({ cancel }) => { if (!confirm('Apagar este arquivo para todo mundo? Não dá para desfazer.')) cancel(); }}>
					<button class="btn small danger">Apagar</button>
				</form>
			{/if}
		</div>
	</section>

	<Comments comments={data.comments} meId={data.me.id} error={form?.commentError} />
</main>

<style>
	.back { margin-bottom: 8px; }
	.viewer { margin: 8px 0 16px; padding: 8px 8px 22px; background: #fff; border-radius: 8px; display: grid; place-items: center; min-height: 200px; box-shadow: 0 6px 18px rgb(90 69 48 / 0.25); rotate: -0.6deg; animation: pop-in 0.5s var(--bounce) both; }
	.viewer > :global(*) { background: #000; border-radius: 4px; }
	.viewer img, .viewer video { width: 100%; height: auto; max-height: 80vh; object-fit: contain; }
	.state { color: #fff; text-align: center; padding: 24px; display: grid; gap: 12px; justify-items: center; }
	.state img { max-height: 50vh; opacity: 0.6; }
	.like-row { display: flex; align-items: center; gap: 4px; margin: -6px 0 6px -8px; }
	.who { display: flex; gap: 10px; align-items: center; }
	.who p { margin: 0; }
	.cap { display: inline-block; }
	.cap::first-letter { text-transform: uppercase; }
	.caption { position: relative; white-space: pre-wrap; overflow-wrap: anywhere; font-size: 1.05rem; margin: 14px 0 4px; background: var(--surface); border: 2.5px solid var(--line); border-radius: 18px; padding: 10px 14px; box-shadow: 0 3px 0 var(--shadow); }
	.link { background: none; border: 0; padding: 0; color: var(--pine); text-decoration: underline; cursor: pointer; min-height: 36px; }
	.place { margin-top: 20px; display: grid; gap: 8px; }
	.who strong { font-family: var(--font-display); font-weight: 600; font-size: 1.1rem; }
	.place p { margin: 0; }
	.file { margin-top: 20px; display: grid; gap: 8px; }
	.file p { margin: 0; overflow-wrap: anywhere; }
	.stack { display: grid; gap: 8px; margin-top: 12px; }
	.row { display: flex; gap: 8px; justify-content: flex-end; flex-wrap: wrap; }
	.row.start { justify-content: flex-start; }
</style>
