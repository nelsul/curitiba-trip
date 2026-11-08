<script lang="ts">
	import Icon from '$lib/components/Icon.svelte';
	import Reel from '$lib/components/Reel.svelte';

	let { data } = $props();
	const byId = $derived(new Map(data.persons.map((p) => [p.id, p])));
	let muted = $state(false);
</script>

<svelte:head><title>Galeria · Viagem a Curitiba</title></svelte:head>

<main class="reels" aria-label="Galeria de fotos e vídeos">
	{#each data.media as m (m.id)}
		<Reel {m} person={byId.get(m.userId)} meId={data.me.id} bind:muted />
	{:else}
		<div class="empty">
			<span class="empty-art"><Icon name="gallery" size={56} stroke={1.8} /></span>
			<p>Nenhuma foto ou vídeo ainda.</p>
			<a class="btn sun" href="/enviar">Enviar fotos e vídeos</a>
		</div>
	{/each}
</main>

<style>
	.reels {
		height: calc(100dvh - 64px - env(safe-area-inset-top) - var(--nav-h) - 10px - env(safe-area-inset-bottom));
		overflow-y: auto; scroll-snap-type: y mandatory; overscroll-behavior-y: contain; scrollbar-width: none;
		background: #000; max-width: 600px; margin: 0 auto;
	}
	.reels::-webkit-scrollbar { display: none; }
	.empty { height: 100%; display: grid; place-content: center; justify-items: center; gap: 12px; text-align: center; padding: 16px; color: var(--ink); background: var(--bg); }
	.empty p { margin: 0; }
	.empty-art { color: var(--sun); }
	@media (min-width: 820px) {
		.reels { height: calc(100dvh - 64px); border-radius: 0; }
	}
</style>
