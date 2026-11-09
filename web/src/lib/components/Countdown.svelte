<script lang="ts">
	import { onMount } from 'svelte';
	import Icon from './Icon.svelte';
	import { WEDDING_AT } from '$lib/trip';

	/** Countdown to the wedding at the top of the Diário; afterwards, the way into the Retrospectiva. */
	let { big = false }: { big?: boolean } = $props();
	const target = new Date(WEDDING_AT).getTime();
	let now = $state(Date.now());
	onMount(() => {
		const t = setInterval(() => (now = Date.now()), 1000);
		return () => clearInterval(t);
	});
	const left = $derived(Math.max(0, target - now));
	const parts = $derived([
		{ n: Math.floor(left / 86_400_000), l: 'dias' },
		{ n: Math.floor(left / 3_600_000) % 24, l: 'horas' },
		{ n: Math.floor(left / 60_000) % 60, l: 'min' },
		{ n: Math.floor(left / 1000) % 60, l: 'seg' }
	]);
</script>

{#if left > 0}
	<a class="count card" class:big href="/retro" aria-label="Faltam {parts[0].n} dias e {parts[1].n} horas para o casamento">
		<span class="ring"><Icon name="ring" size={big ? 40 : 28} /></span>
		<div class="txt">
			<span class="k small">Contagem para o casamento</span>
			<div class="nums" aria-hidden="true">
				{#each parts as p (p.l)}<span><strong>{String(p.n).padStart(2, '0')}</strong><i>{p.l}</i></span>{/each}
			</div>
		</div>
	</a>
{:else}
	<a class="count card done" class:big href="/retro">
		<span class="ring"><Icon name="sparkle" size={big ? 40 : 28} /></span>
		<div class="txt">
			<strong class="t">Retrospectiva da viagem</strong>
			<span class="small">Os melhores momentos, escolhidos a dedo. Toque para ver.</span>
		</div>
	</a>
{/if}

<style>
	.count { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; text-decoration: none; color: var(--ink); background: linear-gradient(135deg, color-mix(in srgb, var(--berry) 30%, var(--surface)), var(--surface)); border-color: color-mix(in srgb, var(--berry) 60%, var(--line)); }
	.ring { flex: none; display: grid; place-items: center; width: 52px; height: 52px; border-radius: 16px; background: var(--berry); color: #fff; animation: bob 3s ease-in-out infinite; }
	.big .ring { width: 72px; height: 72px; }
	.txt { display: grid; gap: 2px; min-width: 0; }
	.k { font-weight: 800; color: var(--berry); }
	.nums { display: flex; gap: 10px; }
	.nums span { display: grid; justify-items: center; line-height: 1; }
	.nums strong { font: 600 1.6rem var(--font-display); font-variant-numeric: tabular-nums; }
	.big .nums strong { font-size: 2.4rem; }
	.nums i { font-style: normal; font-size: 0.7rem; color: var(--muted); font-weight: 800; margin-top: 2px; }
	.t { font: 600 1.2rem var(--font-display); }
	.done { background: linear-gradient(135deg, color-mix(in srgb, var(--sun) 30%, var(--surface)), color-mix(in srgb, var(--berry) 25%, var(--surface))); }
	.done .ring { background: var(--sun); color: var(--on-sun); }
</style>
