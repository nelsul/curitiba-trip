<script lang="ts">
	import Icon from './Icon.svelte';
	import { fmtDuration } from '$lib/format';
	import type { FeedMedia } from '$lib/types';

	/** Every photo and video in a square grid, like a phone's gallery. In `selecting` mode taps pick items. */
	let {
		media,
		selecting = false,
		selected = $bindable([]),
		max = 99,
		onopen
	}: { media: FeedMedia[]; selecting?: boolean; selected?: string[]; max?: number; onopen: (id: string) => void } = $props();

	function tap(m: FeedMedia) {
		if (!selecting) return onopen(m.id);
		if (selected.includes(m.id)) selected = selected.filter((id) => id !== m.id);
		else if (selected.length < max) selected = [...selected, m.id];
	}
</script>

<ul class="grid" aria-label="Todas as fotos e vídeos">
	{#each media as m (m.id)}
		{@const n = selected.indexOf(m.id)}
		<li>
			<button class="cell" class:on={n >= 0} onclick={() => tap(m)} aria-pressed={selecting ? n >= 0 : undefined}
				aria-label="{m.kind === 'video' ? 'Vídeo' : 'Foto'}{m.caption ? `: ${m.caption}` : ''}">
				{#if m.thumb ?? m.image}<img src={m.thumb ?? m.image} alt="" loading="lazy" draggable="false" />{/if}
				{#if m.kind === 'video'}<span class="vid"><Icon name="play" size={12} />{m.durationS ? fmtDuration(m.durationS) : ''}</span>{/if}
				{#if selecting}<span class="tick" class:on={n >= 0}>{n >= 0 ? n + 1 : ''}</span>{/if}
			</button>
		</li>
	{:else}
		<li class="empty muted">Nenhuma foto ou vídeo ainda.</li>
	{/each}
</ul>

<style>
	.grid { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(3, 1fr); gap: 3px; }
	.cell { position: relative; display: block; width: 100%; aspect-ratio: 1; padding: 0; border: 0; background: var(--surface-2); cursor: pointer; overflow: hidden; }
	.cell img { width: 100%; height: 100%; object-fit: cover; display: block; transition: transform 0.2s; }
	.cell.on img { transform: scale(0.88); border-radius: 8px; }
	.vid { position: absolute; right: 4px; bottom: 4px; display: inline-flex; align-items: center; gap: 2px; padding: 1px 6px; border-radius: 999px; background: rgb(0 0 0 / 0.6); color: #fff; font-size: 0.72rem; font-weight: 800; }
	.vid :global(svg) { fill: #fff; }
	.tick { position: absolute; top: 6px; right: 6px; width: 26px; height: 26px; border-radius: 50%; border: 2.5px solid #fff; background: rgb(0 0 0 / 0.25); color: var(--on-sea); font-weight: 800; font-size: 0.85rem; display: grid; place-items: center; }
	.tick.on { background: var(--sea); }
	.empty { grid-column: 1 / -1; padding: 24px; text-align: center; }
	@media (min-width: 700px) { .grid { gap: 6px; } .cell { border-radius: 10px; } }
</style>
