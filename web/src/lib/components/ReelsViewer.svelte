<script lang="ts">
	import { onMount, tick } from 'svelte';
	import Icon from './Icon.svelte';
	import Reel from './Reel.svelte';
	import type { FeedMedia, Person } from '$lib/types';
	import { isGuest } from '$lib/guest';

	/** Full-screen vertical reels over the feed, starting at the post that was tapped. */
	let {
		media,
		start,
		persons,
		meId,
		isAdmin = false,
		onclose,
		onshare,
		ondelete
	}: {
		media: FeedMedia[];
		start: string;
		persons: Map<string, Person>;
		meId: string;
		isAdmin?: boolean;
		onclose: () => void;
		onshare: (id: string) => void;
		ondelete: (id: string) => void;
	} = $props();

	const guest = isGuest();
	let list: HTMLDivElement;
	let muted = $state(false);
	// Only the reels around the one on screen are built: "Todas as fotos" can open this with thousands of items,
	// and building every one at once froze Safari for seconds. The rest are empty slots of the same height.
	const NEAR = 2;
	// svelte-ignore state_referenced_locally
	let current = $state(Math.max(0, media.findIndex((m) => m.id === start)));

	function onscroll() {
		const h = list.clientHeight;
		if (h) current = Math.min(media.length - 1, Math.max(0, Math.round(list.scrollTop / h)));
	}

	onMount(() => {
		const prev = document.body.style.overflow;
		document.body.style.overflow = 'hidden';
		tick().then(() => document.getElementById(`reel-${start}`)?.scrollIntoView({ block: 'start' }));
		list.focus();
		return () => (document.body.style.overflow = prev);
	});
</script>

<svelte:window onkeydown={(e) => e.key === 'Escape' && onclose()} />

<div class="viewer" role="dialog" aria-modal="true" aria-label="Fotos e vídeos em tela cheia">
	<div class="reels" bind:this={list} tabindex="-1" {onscroll}>
		{#each media as m, n (m.id)}
			<div class="slot" id="reel-{m.id}">
				{#if Math.abs(n - current) <= NEAR}<Reel {m} person={persons.get(m.userId)} {meId} bind:muted
					onshare={m.kind === 'photo' && !guest ? () => onshare(m.id) : undefined}
					ondelete={m.userId === meId || isAdmin ? () => ondelete(m.id) : undefined} />{/if}
			</div>
		{/each}
	</div>
	<button class="close" onclick={onclose} aria-label="Voltar ao diário"><Icon name="close" size={22} /></button>
</div>

<style>
	.viewer { position: fixed; inset: 0; z-index: 60; background: #000; }
	.reels { height: 100%; overflow-y: auto; scroll-snap-type: y mandatory; overscroll-behavior: contain; scrollbar-width: none; max-width: 600px; margin: 0 auto; outline: none; }
	.reels::-webkit-scrollbar { display: none; }
	.slot { height: 100dvh; }
	.close {
		position: fixed; top: calc(12px + env(safe-area-inset-top)); left: 12px; z-index: 2; width: 44px; height: 44px; border-radius: 50%;
		border: 1.5px solid rgb(255 255 255 / 0.22); background: rgb(20 24 36 / 0.42); color: #fff; display: grid; place-items: center; cursor: pointer;
		-webkit-backdrop-filter: blur(10px); backdrop-filter: blur(10px);
	}
</style>
