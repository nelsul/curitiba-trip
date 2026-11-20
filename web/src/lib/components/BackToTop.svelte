<script lang="ts">
	import Icon from './Icon.svelte';

	/** "Voltar ao topo": a round button that shows up once you've scrolled a few screens down. */
	let { raised = false }: { raised?: boolean } = $props();
	let y = $state(0);
	let h = $state(800);
</script>

<svelte:window bind:scrollY={y} bind:innerHeight={h} />

{#if y > h * 1.5}
	<button class="top-btn" class:raised onclick={() => window.scrollTo({ top: 0, behavior: 'smooth' })} aria-label="Voltar ao topo">
		<Icon name="up" size={20} /><span>Topo</span>
	</button>
{/if}

<style>
	.top-btn {
		position: fixed; z-index: 24; right: 14px; bottom: calc(var(--nav-h) + 20px + env(safe-area-inset-bottom));
		display: inline-flex; align-items: center; gap: 4px; min-height: 44px; padding: 0 14px 0 10px; border-radius: 999px;
		background: var(--sea); color: var(--on-sea); border: 0; font: 600 0.95rem var(--font-display); cursor: pointer;
		box-shadow: inset 0 -3px 0 var(--sea-dark), 0 4px 12px rgb(0 0 0 / 0.3); animation: pop-in 0.3s var(--bounce);
		-webkit-tap-highlight-color: transparent;
	}
	.top-btn.raised { bottom: calc(var(--nav-h) + 92px + env(safe-area-inset-bottom)); }
	.top-btn:active { transform: scale(0.94); }
	@media (min-width: 820px) { .top-btn { bottom: 24px; } }
</style>
