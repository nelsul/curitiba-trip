<script lang="ts">
	import { mentionParts } from '$lib/mentions';
	import type { Person, PreviewComment } from '$lib/types';

	/** The first two comments under a post (Instagram-style), and a link to the rest. */
	let { first, total, persons, href }: { first: PreviewComment[]; total: number; persons: Map<string, Person>; href: string } = $props();
	const people = $derived([...persons.values()]);
</script>

{#if first.length}
	<ul class="comments">
		{#each first as c (c.id)}
			<li>
				<strong>{persons.get(c.userId)?.name ?? 'Alguém'}</strong>
				{#each mentionParts(c.body, people) as part, i (i)}{#if part.mention}<span class="mention">{part.text}</span>{:else}{part.text}{/if}{/each}
			</li>
		{/each}
	</ul>
{/if}
{#if total > first.length}
	<a class="small muted more" {href}>Ver {first.length ? 'todos os' : 'os'} {total} comentários</a>
{:else if total === 1 && !first.length}
	<a class="small muted more" {href}>Ver 1 comentário</a>
{/if}

<style>
	.comments { list-style: none; margin: 0; padding: 0; display: grid; gap: 2px; }
	li { white-space: pre-wrap; overflow-wrap: anywhere; display: -webkit-box; -webkit-line-clamp: 2; line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
	strong { font-weight: 800; margin-right: 4px; }
	.mention { color: var(--sea); font-weight: 800; }
	.more { color: var(--muted); text-decoration: none; font-weight: 700; }
</style>
