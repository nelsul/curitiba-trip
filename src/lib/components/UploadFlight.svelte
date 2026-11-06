<script lang="ts">
	import Icon from './Icon.svelte';

	let { progress, done = false, failed = false, label = '' }: { progress: number; done?: boolean; failed?: boolean; label?: string } = $props();
	const pct = $derived(Math.max(0, Math.min(1, done ? 1 : progress)) * 100);
	const confetti = Array.from({ length: 12 }, (_, i) => ({
		angle: (i / 12) * 360 + (i % 2 ? 12 : -8),
		dist: 34 + (i % 3) * 12,
		color: ['var(--leaf)', 'var(--sun)', 'var(--coral)', 'var(--sea)', 'var(--berry)'][i % 5],
		round: i % 3 === 0
	}));
</script>

<div class="flight" class:done class:failed role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow={Math.round(pct)} aria-label={label || 'Envio'}>
	<span class="end start"><Icon name="camera" size={16} /></span>
	<div class="route">
		<span class="flown" style:width="{pct}%"></span>
		<span class="plane" style:left="{pct}%"><Icon name="plane" size={22} stroke={1.6} /></span>
	</div>
	<span class="end goal"><Icon name="island" size={16} /></span>

	{#if done}
		<span class="stamp-done" aria-hidden="true">Chegou!</span>
		<span class="burst" aria-hidden="true">
			{#each confetti as c}
				<i style:--a="{c.angle}deg" style:--r="{c.dist}px" style:background={c.color} class:round={c.round}></i>
			{/each}
		</span>
	{/if}
</div>

<style>
	.flight { position: relative; display: grid; grid-template-columns: auto 1fr auto; align-items: center; gap: 6px; height: 36px; margin-top: 4px; }
	.end { display: grid; place-items: center; width: 28px; height: 28px; border-radius: 50%; background: var(--surface-2); color: var(--muted); border: 2px solid var(--line); }
	.goal { transition: background 0.3s, color 0.3s; }
	.done .goal { background: var(--leaf); color: var(--on-leaf); border-color: var(--leaf); animation: pop-in 0.5s var(--bounce); }
	.route { position: relative; height: 4px; margin: 0 10px; background-image: radial-gradient(circle, var(--line) 2px, transparent 2.5px); background-size: 10px 4px; }
	.flown { position: absolute; left: 0; top: 0; height: 4px; background-image: radial-gradient(circle, var(--sea) 2.2px, transparent 2.6px); background-size: 10px 4px; transition: width 0.3s linear; }
	.plane {
		position: absolute; top: 50%; translate: -50% -50%; color: var(--sea); transition: left 0.3s linear;
		filter: drop-shadow(0 2px 0 rgb(0 0 0 / 0.15)); animation: fly 1.2s ease-in-out infinite;
	}
	.plane :global(svg) { fill: var(--sea); stroke: var(--surface); rotate: 90deg; }
	.done .plane { animation: land 0.5s ease-out forwards; }
	.failed .plane { color: var(--danger); animation: none; }
	.failed .plane :global(svg) { fill: var(--danger); }
	@keyframes fly { 0%, 100% { transform: translateY(-2px) rotate(-3deg); } 50% { transform: translateY(2px) rotate(3deg); } }
	@keyframes land { to { transform: translateY(0) scale(0.6); opacity: 0; } }
	.stamp-done {
		position: absolute; right: 30px; top: -16px; font: 600 0.95rem var(--font-display); text-transform: uppercase; letter-spacing: 0.06em;
		color: var(--coral); border: 3px double var(--coral); border-radius: 8px; padding: 1px 8px; background: var(--surface);
		animation: stamp-in 0.5s var(--bounce) both;
	}
	.burst { position: absolute; right: 14px; top: 50%; width: 0; height: 0; }
	.burst i {
		position: absolute; width: 8px; height: 5px; border-radius: 2px; left: -4px; top: -2px;
		animation: confetti 0.9s cubic-bezier(0.2, 0.8, 0.3, 1) forwards;
	}
	.burst i.round { width: 6px; height: 6px; border-radius: 50%; }
	@keyframes confetti {
		0% { transform: rotate(var(--a)) translateX(0) rotate(0); opacity: 1; }
		80% { opacity: 1; }
		100% { transform: rotate(var(--a)) translateX(var(--r)) rotate(260deg) translateY(10px); opacity: 0; }
	}
</style>
