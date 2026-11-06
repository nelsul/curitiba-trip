<script lang="ts">
	import { dayKeyLabel } from '$lib/format';
	import { WEDDING_DAY } from '$lib/trip';
	import type { Person } from '$lib/types';
	import Avatar from './Avatar.svelte';
	import Icon from './Icon.svelte';

	let {
		days,
		persons,
		day = $bindable('all'),
		person = $bindable('all')
	}: { days: string[]; persons: Person[]; day: string; person: string } = $props();
</script>

<div class="filters">
	<div class="chips" role="group" aria-label="Dia">
		<button class="chip" aria-pressed={day === 'all'} onclick={() => (day = 'all')}><Icon name="calendar" size={16} /> Todos os dias</button>
		{#each days as d}
			{@const l = dayKeyLabel(d)}
			<button class="chip day" class:wedding={d === WEDDING_DAY} aria-pressed={day === d} onclick={() => (day = d)}>
				<strong>{l.day}</strong> {l.weekday}
			</button>
		{/each}
	</div>
	<div class="chips" role="group" aria-label="Pessoa">
		<button class="chip" aria-pressed={person === 'all'} onclick={() => (person = 'all')}><Icon name="people" size={16} /> Todo mundo</button>
		{#each persons as p}
			<button class="chip person" aria-pressed={person === p.id} onclick={() => (person = person === p.id ? 'all' : p.id)}>
				<Avatar name={p.name} color={p.color} photo={p.photo} size={24} /> {p.name}
			</button>
		{/each}
	</div>
</div>

<style>
	.filters { display: grid; gap: 8px; margin: 12px 0 16px; }
	.chip.day { border-style: dashed; }
	.chip.wedding:not([aria-pressed='true']) { border-color: var(--berry); color: var(--berry); }
	.chip.wedding::after { content: ''; width: 7px; height: 7px; border-radius: 50%; background: currentColor; display: inline-block; margin-left: 6px; vertical-align: middle; }
	.chip { display: inline-flex; align-items: center; gap: 6px; }
	.chip.person { display: inline-flex; align-items: center; gap: 6px; padding-left: 6px; }
</style>
