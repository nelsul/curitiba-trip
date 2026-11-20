<script lang="ts">
	import Icon from './Icon.svelte';

	let {
		mediaId,
		favs,
		meId,
		size = 26,
		onchange
	}: { mediaId: string; favs: string[]; meId: string; size?: number; onchange: (favs: string[]) => void } = $props();

	const on = $derived(favs.includes(meId));
	let burst = $state(0);
	let pending: Promise<unknown> = Promise.resolve();

	/** Star or unstar for the Retrospectiva. Optimistic, like the heart. */
	function toggle() {
		const next = !on;
		const before = favs;
		onchange(next ? [...favs, meId] : favs.filter((id) => id !== meId));
		if (next) burst++;
		pending = pending.then(async () => {
			try {
				const r = await fetch('/api/favorites', {
					method: 'POST',
					headers: { 'content-type': 'application/json' },
					body: JSON.stringify({ mediaId, fav: next })
				});
				if (!r.ok) throw new Error();
				onchange((await r.json()).favs);
			} catch {
				onchange(before);
			}
		});
	}
</script>

<button type="button" class="fav" class:on onclick={toggle} aria-pressed={on}
	aria-label={on ? 'Tirar dos favoritos' : 'Favoritar para a retrospectiva'} title={on ? 'Tirar dos favoritos' : 'Favoritar (vai para a retrospectiva)'}>
	{#key burst}<span class="star" class:pop={burst > 0 && on}><Icon name="star" {size} stroke={2.2} /></span>{/key}
</button>

<style>
	.fav { display: grid; place-items: center; min-width: 44px; min-height: 44px; padding: 0; border: 0; background: none; color: inherit; cursor: pointer; -webkit-tap-highlight-color: transparent; }
	.star { display: grid; transition: transform 0.1s; }
	.fav:active .star { transform: scale(0.85); }
	.on { color: var(--sun); }
	.on .star :global(svg) { fill: currentColor; }
	.pop { animation: star-pop 0.5s var(--bounce); }
	@keyframes star-pop { 0% { transform: scale(0.5) rotate(-30deg); } 55% { transform: scale(1.35) rotate(12deg); } 100% { transform: scale(1) rotate(0); } }
</style>
