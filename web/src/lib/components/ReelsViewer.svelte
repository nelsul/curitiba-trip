<script lang="ts">
	import { onMount, tick } from 'svelte';
	import Icon from './Icon.svelte';
	import Reel from './Reel.svelte';
	import type { FeedMedia, Person } from '$lib/types';

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

	let list: HTMLDivElement;
	let muted = $state(false);

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
	<div class="reels" bind:this={list} tabindex="-1">
		{#each media as m (m.id)}
			<div class="slot" id="reel-{m.id}">
				<Reel {m} person={persons.get(m.userId)} {meId} bind:muted
					onshare={m.kind === 'photo' ? () => onshare(m.id) : undefined}
					ondelete={m.userId === meId || isAdmin ? () => ondelete(m.id) : undefined} />
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
		border: 0; background: rgb(0 0 0 / 0.45); color: #fff; display: grid; place-items: center; cursor: pointer;
	}
</style>
