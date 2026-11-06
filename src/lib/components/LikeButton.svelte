<script lang="ts">
	import Icon from './Icon.svelte';

	let {
		target,
		likers,
		meId,
		size = 28,
		onchange
	}: {
		target: { mediaId: string } | { checkinId: string };
		likers: string[];
		meId: string;
		size?: number;
		onchange: (likers: string[]) => void;
	} = $props();

	const liked = $derived(likers.includes(meId));
	let burst = $state(0);
	let pending: Promise<unknown> = Promise.resolve();

	/** Toggle (or force) the like. Optimistic: the heart reacts instantly, the server catches up. */
	export function set(next: boolean) {
		if (next === liked) {
			if (next) burst++; // double-tap on an already-liked photo still celebrates
			return;
		}
		const before = likers;
		onchange(next ? [...likers, meId] : likers.filter((id) => id !== meId));
		if (next) burst++;
		pending = pending.then(async () => {
			try {
				const r = await fetch('/api/likes', {
					method: 'POST',
					headers: { 'content-type': 'application/json' },
					body: JSON.stringify({ ...target, liked: next })
				});
				if (!r.ok) throw new Error();
				onchange((await r.json()).likers);
			} catch {
				onchange(before);
			}
		});
	}
</script>

<button type="button" class="like" class:liked onclick={() => set(!liked)} aria-pressed={liked} aria-label={liked ? 'Descurtir' : 'Curtir'}>
	{#key burst}
		<span class="heart" class:pop={burst > 0 && liked}><Icon name="heart" {size} stroke={2.2} /></span>
		{#if burst > 0 && liked}
			<span class="sparks" aria-hidden="true">{#each Array(6) as _, i}<i style:--a="{i * 60}deg"></i>{/each}</span>
		{/if}
	{/key}
</button>

<style>
	.like { position: relative; display: grid; place-items: center; min-width: 44px; min-height: 44px; padding: 0; border: 0; background: none; color: var(--ink); cursor: pointer; -webkit-tap-highlight-color: transparent; }
	.like:active .heart { transform: scale(0.85); }
	.heart { display: grid; transition: transform 0.1s; }
	.liked { color: var(--berry); }
	.liked .heart :global(svg) { fill: currentColor; }
	.pop { animation: heart-pop 0.45s var(--bounce); }
	@keyframes heart-pop { 0% { transform: scale(0.6); } 50% { transform: scale(1.35); } 100% { transform: scale(1); } }
	.sparks { position: absolute; left: 50%; top: 50%; width: 0; height: 0; pointer-events: none; }
	.sparks i { position: absolute; left: -3px; top: -3px; width: 6px; height: 6px; border-radius: 50%; background: var(--berry); animation: spark 0.55s ease-out forwards; }
	.sparks i:nth-child(even) { background: var(--sun); }
	@keyframes spark { from { transform: rotate(var(--a)) translateY(0) scale(1); opacity: 1; } to { transform: rotate(var(--a)) translateY(-24px) scale(0.3); opacity: 0; } }
</style>
