<script lang="ts">
	import Avatar from './Avatar.svelte';
	import type { Person } from '$lib/types';

	let { likers, persons, meId }: { likers: string[]; persons: Map<string, Person>; meId: string } = $props();

	// "you" first, then most recent likers
	const ordered = $derived([...likers].reverse().sort((a, b) => Number(b === meId) - Number(a === meId)));
	const first = $derived(ordered[0] ? persons.get(ordered[0]) : undefined);
	const name = (id: string) => (id === meId ? 'você' : (persons.get(id)?.name ?? 'alguém'));
</script>

{#if likers.length}
	<p class="liked-by">
		<span class="stack" aria-hidden="true">
			{#each ordered.slice(0, 3) as id (id)}
				{@const p = persons.get(id)}
				{#if p}<Avatar name={p.name} color={p.color} photo={p.photo} size={22} />{/if}
			{/each}
		</span>
		<span>
			Curtido por <strong>{first ? name(ordered[0]) : 'alguém'}</strong>
			{#if likers.length === 2} e <strong>{name(ordered[1])}</strong>{:else if likers.length > 2} e <strong>mais {likers.length - 1}</strong>{/if}
		</span>
	</p>
{/if}

<style>
	.liked-by { display: flex; align-items: center; gap: 8px; margin: 0; font-size: 0.92rem; }
	.stack { display: inline-flex; }
	.stack :global(.avatar) { border-width: 2px; margin-left: -8px; box-shadow: none; }
	.stack :global(.avatar:first-child) { margin-left: 0; }
	strong { font-weight: 800; }
</style>
