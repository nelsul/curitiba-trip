<script lang="ts">
	import { DAYS, PLACES, TRANSPORT, placeUrl, routeUrl, uberUrl } from '$lib/itinerary';
	import { dayKey, dayKeyLabel } from '$lib/format';
	import Icon from '$lib/components/Icon.svelte';
	import { fly } from 'svelte/transition';
	import { backOut } from 'svelte/easing';

	const today = dayKey(Date.now());
	let selected = $state(DAYS.find((d) => d.date === today)?.date ?? DAYS[0].date);
	const day = $derived(DAYS.find((d) => d.date === selected)!);
	const route = $derived(routeUrl(day));
	const idx = $derived(DAYS.indexOf(day));
</script>

<svelte:head><title>Roteiro · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<div class="title-row"><span class="title-icon"><Icon name="ticket" size={26} /></span><h1>Roteiro</h1></div>
	<div class="chips days" role="tablist" aria-label="Dias">
		{#each DAYS as d}
			{@const l = dayKeyLabel(d.date)}
			<button role="tab" class="chip daybtn" class:wedding={d.wedding} class:today={d.date === today} aria-selected={selected === d.date} onclick={() => (selected = d.date)}>
				<strong>{l.day}</strong><span>{l.weekday}</span>
			</button>
		{/each}
	</div>

	{#key selected}
		<article class="ticket" class:wedding={day.wedding} in:fly={{ x: 40, duration: 420, easing: backOut }}>
			<header class="ticket-head">
				<div>
					<p class="kicker">{day.wedding ? 'Dia especial' : `Dia ${idx + 1} de ${DAYS.length}`}</p>
					<h2>{day.title}</h2>
				</div>
				<div class="date-stamp"><strong>{day.date.slice(8)}</strong><span>nov</span></div>
			</header>
			<div class="perf" aria-hidden="true"></div>
			<div class="ticket-body">
				<p class="who small"><Icon name="people" size={16} /> {day.who}</p>
				<p class="lead">{day.lead}</p>
				<ol class="stops">
					{#each day.stops as s, i}
						{@const p = s.place ? PLACES[s.place] : null}
						<li style:animation-delay="{120 + i * 70}ms">
							<span class="time">{s.time}</span>
							<div class="stop card">
								<h3>{p?.name ?? s.label}</h3>
								<span class="badge" style:--c={TRANSPORT[s.transport].color}>{TRANSPORT[s.transport].label}</span>
								<p>{s.note}</p>
								{#if p?.hours}<p class="small muted">Horário: {p.hours}</p>{/if}
								{#if p}
									<div class="stop-actions">
										<a class="btn small uber" href={uberUrl(p)} target="_blank" rel="noopener"><Icon name="car" size={18} /> Pedir Uber</a>
										<a class="btn small secondary" href={placeUrl(p)} target="_blank" rel="noopener"><Icon name="pin" size={18} /> Mapa</a>
									</div>
								{/if}
							</div>
						</li>
					{/each}
				</ol>
				{#if route && !day.wedding}
					<a class="btn sea block" href={route} target="_blank" rel="noopener"><Icon name="map" size={20} /> Rota do dia no Google Maps</a>
				{/if}
			</div>
		</article>
	{/key}
</main>

<style>
	.days { margin: 8px 0 14px; }
	.daybtn { display: grid; justify-items: center; line-height: 1.15; min-width: 56px; padding: 6px 10px; border-style: dashed; }
	.daybtn span { font-size: 0.75rem; }
	.daybtn.today { position: relative; }
	.daybtn.today::after { content: 'hoje'; position: absolute; top: -9px; right: -6px; font-size: 0.6rem; background: var(--coral); color: #fff; border-radius: 999px; padding: 0 5px; }
	.daybtn.wedding:not([aria-selected='true']) { border-color: var(--berry); color: var(--berry); }

	.ticket { background: var(--surface); border: 2.5px solid var(--line); border-radius: var(--radius); box-shadow: 0 5px 0 var(--shadow); overflow: hidden; }
	.ticket.wedding { border-color: var(--berry); }
	.ticket-head {
		display: flex; justify-content: space-between; align-items: center; gap: 12px; padding: 16px 18px;
		background: var(--sea); color: #fff;
		background-image: repeating-linear-gradient(135deg, transparent 0 14px, rgb(255 255 255 / 0.07) 14px 28px);
	}
	.wedding .ticket-head { background-color: var(--berry); }
	.ticket-head h2 { margin: 0; color: #fff; }
	.kicker { margin: 0 0 2px; font-size: 0.75rem; font-weight: 800; text-transform: uppercase; letter-spacing: 0.1em; opacity: 0.9; }
	.date-stamp {
		flex: none; display: grid; place-items: center; width: 64px; height: 64px; border-radius: 50%; line-height: 1;
		border: 3px dashed rgb(255 255 255 / 0.8); transform: rotate(10deg); font-family: var(--font-display);
	}
	.date-stamp strong { font-size: 1.6rem; }
	.date-stamp span { font-size: 0.75rem; text-transform: uppercase; }
	.perf { height: 0; border-top: 3px dashed var(--line); margin: 0 14px; position: relative; }
	.perf::before, .perf::after { content: ''; position: absolute; top: -12px; width: 22px; height: 22px; border-radius: 50%; background: var(--bg); border: 2.5px solid var(--line); }
	.perf::before { left: -27px; }
	.perf::after { right: -27px; }
	.ticket-body { padding: 16px 16px 18px; }
	.ticket-body > p { margin: 0 0 8px; }
	.who { display: flex; gap: 6px; align-items: center; color: var(--muted); font-weight: 700; }
	.lead { font-size: 1.05rem; }
	.stops { list-style: none; padding: 0; margin: 16px 0; display: grid; gap: 14px; }
	.stops li { display: grid; grid-template-columns: 58px 1fr; gap: 10px; align-items: start; animation: pop-in 0.45s var(--bounce) both; }
	.time {
		margin-top: 12px; text-align: center; font: 600 0.82rem var(--font-display); background: var(--sun); color: #4a3410;
		border-radius: 10px; padding: 3px 2px; box-shadow: 0 2px 0 var(--sun-dark);
	}
	.stop { padding: 12px 14px; box-shadow: 0 3px 0 var(--shadow); }
	.stop p { margin: 6px 0 0; }
	h3 { margin: 0 0 6px; }
	.badge { display: inline-block; border: 2px solid var(--c); color: var(--c); border-radius: 999px; padding: 0 10px; font-size: 0.8rem; font-weight: 800; }
	.stop-actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 10px; }
	.btn.uber { --b: #1b1b1b; --b-dark: #000; --b-ink: #fff; }
</style>
