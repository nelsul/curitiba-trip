<script lang="ts">
	import Icon from './Icon.svelte';
	import { WEATHER_LABEL, type WeatherDay } from '$lib/weather';
	import { dayKey } from '$lib/format';

	/** One day's forecast: the summary and an hour-by-hour strip (scrolled to now on today, else to 8h). */
	let { day, compact = false }: { day: WeatherDay; compact?: boolean } = $props();

	const hours = $derived(day.hours.filter((h) => Number(h.time.slice(0, 2)) >= 6));
	let strip = $state<HTMLDivElement>();
	$effect(() => {
		if (!strip) return;
		const now = new Date().toLocaleString('en-GB', { timeZone: 'America/Sao_Paulo', hour: '2-digit', hour12: false });
		const target = day.date === dayKey(Date.now()) ? Number(now) : 8;
		const i = Math.max(0, hours.findIndex((h) => Number(h.time.slice(0, 2)) >= target));
		const el = strip.children[i] as HTMLElement | undefined;
		if (el) strip.scrollLeft = el.offsetLeft - strip.offsetLeft - 8;
	});
	const tempColor = (t: number) => (t >= 26 ? 'var(--coral)' : t >= 20 ? 'var(--sun)' : t >= 14 ? 'var(--leaf)' : 'var(--sky)');
</script>

<section class="weather" aria-label="Previsão do tempo">
	<div class="sum">
		<span class="ico" style:--c={tempColor(day.max)}><Icon name={day.kind} size={compact ? 26 : 34} /></span>
		<div>
			<strong>{day.min}° a {day.max}°</strong>
			<span class="small muted">{WEATHER_LABEL[day.kind]}{day.rain >= 20 ? ` · ${day.rain}% de chuva` : ''}</span>
		</div>
	</div>
	<div class="hours" bind:this={strip} role="list" aria-label="Hora a hora">
		{#each hours as h (h.time)}
			<div class="h" role="listitem" aria-label="{h.time}: {h.temp} graus, {WEATHER_LABEL[h.kind]}{h.rain >= 20 ? `, ${h.rain}% de chuva` : ''}">
				<span class="t small">{h.time.replace(':00', 'h')}</span>
				<span class="i" style:--c={tempColor(h.temp)}><Icon name={h.kind} size={20} /></span>
				<strong>{h.temp}°</strong>
				<span class="r small" class:hide={h.rain < 20}>{h.rain}%</span>
			</div>
		{/each}
	</div>
</section>

<style>
	.weather { display: grid; gap: 8px; padding: 10px 12px; border: 2.5px solid var(--line); border-radius: 18px; background: var(--surface); margin: 8px 0 12px; min-width: 0; }
	.sum { display: flex; align-items: center; gap: 10px; }
	.sum div { display: grid; line-height: 1.2; }
	.sum strong { font: 600 1.15rem var(--font-display); }
	.ico, .i { color: var(--c); display: grid; place-items: center; }
	.hours { display: flex; gap: 4px; overflow-x: auto; scrollbar-width: none; scroll-snap-type: x proximity; margin: 0 -4px; padding: 0 4px; }
	.hours::-webkit-scrollbar { display: none; }
	.h { flex: 0 0 auto; display: grid; justify-items: center; gap: 2px; min-width: 46px; padding: 6px 2px; border-radius: 12px; background: var(--surface-2); scroll-snap-align: start; }
	.t { color: var(--muted); font-weight: 800; }
	.h strong { font-size: 0.95rem; }
	.r { color: var(--sky); font-weight: 800; font-size: 0.72rem; }
	.r.hide { visibility: hidden; }
</style>
