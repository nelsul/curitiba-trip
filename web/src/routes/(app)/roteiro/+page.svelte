<script lang="ts">
	import { goto, invalidate } from '$app/navigation';
	import { page } from '$app/state';
	import { fly } from 'svelte/transition';
	import { backOut } from 'svelte/easing';
	import Icon from '$lib/components/Icon.svelte';
	import PlaceCard from '$lib/components/roteiro/PlaceCard.svelte';
	import PlaceEditor from '$lib/components/roteiro/PlaceEditor.svelte';
	import DayEditor from '$lib/components/roteiro/DayEditor.svelte';
	import RouteMap from '$lib/components/roteiro/RouteMap.svelte';
	import StayEditor from '$lib/components/roteiro/StayEditor.svelte';
	import WeatherCard from '$lib/components/WeatherCard.svelte';
	import type { WeatherDay } from '$lib/weather';
	import { dayKey, dayKeyLabel } from '$lib/format';
	import {
		CATEGORY,
		STAY_KIND,
		TRANSPORT,
		placeUrl,
		priceSigns,
		routeUrl,
		uberUrl,
		type PlaceCategory,
		type RoteiroPlace,
		type RoteiroStay
	} from '$lib/itinerary';
	import { api } from '$lib/roteiro-client';
	import { onMount } from 'svelte';

	let { data } = $props();
	/** only admins change places and days; everyone ticks "Fomos!" */
	const admin = $derived(data.me.isAdmin);

	/** computers: the day's map moves to a column beside the stops */
	let wide = $state(false);
	onMount(() => {
		const mq = matchMedia('(min-width: 1000px)');
		const update = () => (wide = mq.matches);
		update();
		mq.addEventListener('change', update);
		return () => mq.removeEventListener('change', update);
	});
	/** forecast per day (loaded after the page, it comes from an outside service) */
	let weather = $state<Record<string, WeatherDay>>({});
	onMount(() => {
		fetch('/api/weather')
			.then((r) => (r.ok ? r.json() : { days: [] }))
			.then((w: { days: WeatherDay[] }) => (weather = Object.fromEntries(w.days.map((d) => [d.date, d]))))
			.catch(() => {});
	});
	/** stop under the mouse, highlighted on the map */
	let hovered = $state<number | null>(null);

	type Tab = 'dias' | 'lugares' | 'hospedagem';
	const tab = $derived.by((): Tab => {
		const a = page.url.searchParams.get('aba');
		return a === 'lugares' || a === 'hospedagem' ? a : 'dias';
	});
	const setTab = (t: Tab) => goto(t === 'dias' ? '?' : `?aba=${t}`, { replaceState: true, noScroll: true, keepFocus: true });
	const reload = () => invalidate('app:roteiro');

	const byId = $derived(new Map(data.places.map((p) => [p.id, p])));
	const MONTHS = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

	// ── Dias ──
	const today = dayKey(Date.now());
	// svelte-ignore state_referenced_locally
	let selected = $state(data.days.find((d) => d.date === today)?.date ?? data.days[0]?.date ?? '');
	const day = $derived(data.days.find((d) => d.date === selected) ?? null);
	const idx = $derived(day ? data.days.indexOf(day) : -1);
	/** the day's stops that have a place, numbered for the map */
	const mapPoints = $derived.by(() => {
		let n = 0;
		return (day?.stops ?? []).flatMap((s) => {
			const p = s.placeId ? byId.get(s.placeId) : undefined;
			return p
				? [{ n: ++n, stopId: s.id, name: p.name, lat: p.lat, lng: p.lng, transport: s.transport, photo: p.photos[0]?.url ?? null, visited: !!visitOf(s).visitedAt }]
				: [];
		});
	});
	const numberOf = $derived(new Map(mapPoints.map((p) => [p.stopId, p.n])));

	// ── where I sleep: the day leaves from there and comes back there ──
	const stayById = $derived(new Map(data.stays.map((s) => [s.id, s])));
	// only on days with somewhere to go
	const startStay = $derived(day?.startStay && mapPoints.length ? (stayById.get(day.startStay) ?? null) : null);
	const endStay = $derived(day?.endStay && mapPoints.length ? (stayById.get(day.endStay) ?? null) : null);
	const homes = $derived.by(() => {
		const h: { id: string; name: string; lat: number; lng: number; emoji: string; label: string }[] = [];
		const pin = (s: RoteiroStay, id: string, label: string) => ({ id, name: s.name, lat: s.lat, lng: s.lng, emoji: STAY_KIND[s.kind].emoji, label });
		if (startStay && endStay && startStay.id === endStay.id) h.push(pin(startStay, 'start', 'Saída e volta'));
		else {
			if (startStay) h.push(pin(startStay, 'start', 'Saída'));
			if (endStay) h.push(pin(endStay, 'end', 'Volta'));
		}
		return h;
	});
	const googleRoute = $derived(routeUrl([...(startStay ? [startStay] : []), ...mapPoints, ...(endStay ? [endStay] : [])]));
	const scrollToHome = (id: string) => document.getElementById(`casa-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
	let editingDay = $state<'new' | 'current' | null>(null);
	const nextDate = $derived.by(() => {
		const last = data.days.at(-1)?.date;
		if (!last) return today;
		const d = new Date(`${last}T12:00:00Z`);
		d.setUTCDate(d.getUTCDate() + 1);
		return d.toISOString().slice(0, 10);
	});

	async function daySaved(date: string | null) {
		editingDay = null;
		await reload();
		selected = date && data.days.some((d) => d.date === date) ? date : (data.days[0]?.date ?? '');
	}
	function scrollToStop(n: number) {
		hovered = n;
		document.getElementById(`parada-${n}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
	}

	// ── "Fomos!" (one tick counts for everyone) ──
	type Visit = { visitedAt: string | null; visitedBy: string | null };
	/** answers from the server not yet in `data` (shown right away, before the reload) */
	let visits = $state<Record<string, Visit>>({});
	const visitOf = (s: { id: string } & Visit): Visit => visits[s.id] ?? s;
	const personName = (id: string | null) => data.persons.find((p) => p.id === id)?.name ?? 'alguém';
	const fmtWhen = (iso: string) =>
		new Date(iso).toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo', day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }).replace(',', '');

	async function toggleVisit(s: { id: string } & Visit) {
		const now = !visitOf(s).visitedAt;
		visits[s.id] = now ? { visitedAt: new Date().toISOString(), visitedBy: data.me.id } : { visitedAt: null, visitedBy: null };
		try {
			visits[s.id] = await api<Visit>('POST', `/api/roteiro/stops/${s.id}/visited`, { visited: now });
			await reload();
			delete visits[s.id];
		} catch (err) {
			delete visits[s.id];
			alert((err as Error).message);
		}
	}

	// ── Hospedagem (admins set it up; everyone sees it) ──
	let editingStay = $state<RoteiroStay | 'new' | null>(null);
	const personOf = (id: string) => data.persons.find((p) => p.id === id);
	const homeless = $derived(data.persons.filter((p) => !data.stays.some((s) => s.guests.includes(p.id))));
	const fmtDay = (key: string) => {
		const l = dayKeyLabel(key);
		return `${l.weekday} ${l.day}/${key.slice(5, 7)}`;
	};

	// ── Lugares ──
	let filter = $state<'todos' | PlaceCategory>('todos');
	let query = $state('');
	let editingPlace = $state<RoteiroPlace | 'new' | null>(null);
	const fold = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();
	/** places someone already ticked as visited on any day */
	const visitedPlaces = $derived(new Set(data.days.flatMap((d) => d.stops.filter((s) => s.placeId && visitOf(s).visitedAt).map((s) => s.placeId!))));
	const usedOn = $derived.by(() => {
		const m = new Map<string, string[]>();
		for (const d of data.days) for (const s of d.stops) if (s.placeId) {
			const l = m.get(s.placeId) ?? m.set(s.placeId, []).get(s.placeId)!;
			if (!l.includes(d.date)) l.push(d.date);
		}
		return m;
	});
	const shown = $derived(
		data.places
			.filter((p) => filter === 'todos' || p.category === filter)
			.filter((p) => !query.trim() || fold(`${p.name} ${p.address} ${p.description}`).includes(fold(query.trim())))
	);
	let toast = $state('');

	/** "Pôr no roteiro": adds the place as the last stop of that day. */
	async function addToDay(place: RoteiroPlace, date: string) {
		const d = data.days.find((x) => x.date === date);
		if (!d) return;
		try {
			await api('PUT', `/api/roteiro/days/${date}`, {
				title: d.title, who: d.who, lead: d.lead, wedding: d.wedding,
				stops: [...d.stops, { time: '', placeId: place.id, label: '', transport: 'uber', note: '' }]
			});
			await reload();
			const l = dayKeyLabel(date);
			toast = `${place.name} entrou no roteiro de ${l.weekday} ${l.day}.`;
			setTimeout(() => (toast = ''), 3000);
		} catch (err) {
			alert((err as Error).message);
		}
	}
</script>

<svelte:head><title>Roteiro · Viagem a Curitiba</title></svelte:head>

{#snippet dayMap(d: typeof day & {})}
	{#if mapPoints.length}
		{#key `${d.date}|${wide}|` + [...homes, ...mapPoints].map((p) => `${p.lat},${p.lng},${'transport' in p ? `${p.transport},${p.photo},${p.visited}` : p.label}`).join('|')}
			<RouteMap date={d.date} points={mapPoints} {homes} onpick={scrollToStop} onpickhome={scrollToHome} active={hovered} height={wide ? 'calc(100dvh - 190px)' : '280px'} />
		{/key}
		<p class="legend small muted">
			{#each Object.entries(TRANSPORT).filter(([k]) => d.stops.some((s) => s.transport === k)) as [, t]}<span style:--c={t.color}><i></i>{t.label}</span>{/each}
		</p>
	{/if}
{/snippet}

{#snippet homeStop(st: RoteiroStay, which: 'start' | 'end')}
	<li class="home-stop" id="casa-{which}">
		<div class="stop card home">
			<div class="stop-top">
				<span class="thumb home-ico" aria-hidden="true">{STAY_KIND[st.kind].emoji}</span>
				<div class="stop-text">
					<div class="when"><span class="time"><Icon name="home" size={14} /> {which === 'start' ? 'Saída' : 'Volta'}</span></div>
					<h3>{st.name}</h3>
					{#if st.address}<p class="small muted">{st.address}</p>{/if}
				</div>
			</div>
			<div class="stop-actions">
				{#if which === 'end'}<a class="btn small uber" href={uberUrl(st)} target="_blank" rel="noopener"><Icon name="car" size={18} /> Uber de volta</a>{/if}
				<a class="btn small secondary icon" href={placeUrl(st)} target="_blank" rel="noopener" aria-label="Abrir {st.name} no Google Maps" title="Google Maps"><Icon name="map" size={18} /></a>
			</div>
		</div>
	</li>
{/snippet}

<main class="page roteiro">
	<div class="title-row"><span class="title-icon"><Icon name="ticket" size={26} /></span><h1>Roteiro</h1></div>

	<div class="tabs" role="tablist" aria-label="Roteiro">
		<button role="tab" aria-selected={tab === 'dias'} onclick={() => setTab('dias')}><Icon name="calendar" size={18} /> Dia a dia</button>
		<button role="tab" aria-selected={tab === 'lugares'} onclick={() => setTab('lugares')}><Icon name="pin" size={18} /> Lugares</button>
		<button role="tab" aria-selected={tab === 'hospedagem'} onclick={() => setTab('hospedagem')}><Icon name="home" size={18} /> Hospedagem</button>
	</div>

	{#if tab === 'dias'}
		<div class="chips days" role="tablist" aria-label="Dias">
			{#each data.days as d (d.date)}
				{@const l = dayKeyLabel(d.date)}
				<button role="tab" class="chip daybtn" class:wedding={d.wedding} class:today={d.date === today} aria-selected={selected === d.date && editingDay !== 'new'} onclick={() => { selected = d.date; editingDay = null; }}>
					<strong>{l.day}</strong><span>{l.weekday}</span>
					{#if weather[d.date]}<span class="wx" aria-label="{weather[d.date].max}°"><Icon name={weather[d.date].kind} size={14} /></span>{/if}
				</button>
			{/each}
			{#if admin}<button role="tab" class="chip daybtn add" aria-label="Adicionar dia" aria-selected={editingDay === 'new'} onclick={() => (editingDay = 'new')}><strong>+</strong><span>dia</span></button>{/if}
		</div>

		<div class="day-layout" class:with-map={wide && editingDay !== 'new' && !!day && mapPoints.length > 0} class:editing={editingDay === 'current'}>
		<div class="day-main">
		{#if editingDay === 'new'}
			<article class="ticket"><div class="ticket-body">
				<h2>Novo dia</h2>
				<DayEditor day={null} places={data.places} takenDates={data.days.map((d) => d.date)} suggestedDate={nextDate} onclose={() => (editingDay = null)} onsaved={daySaved} onplaceschanged={reload} />
			</div></article>
		{:else if day}
			{#key selected}
				<article class="ticket" class:wedding={day.wedding} in:fly={{ x: 40, duration: 420, easing: backOut }}>
					<header class="ticket-head">
						<div>
							<p class="kicker">{day.wedding ? 'Dia especial' : `Dia ${idx + 1} de ${data.days.length}`}</p>
							<h2>{day.title || 'Sem título'}</h2>
						</div>
						<div class="date-stamp"><strong>{day.date.slice(8)}</strong><span>{MONTHS[Number(day.date.slice(5, 7)) - 1]}</span></div>
					</header>
					<div class="perf" aria-hidden="true"></div>
					<div class="ticket-body">
						{#if editingDay === 'current'}
							<DayEditor {day} places={data.places} takenDates={data.days.map((d) => d.date)} suggestedDate={day.date} onclose={() => (editingDay = null)} onsaved={daySaved} onplaceschanged={reload} />
						{:else}
							{#if day.who}<p class="who small"><Icon name="people" size={16} /> {day.who}</p>{/if}
							{#if day.lead}<p class="lead">{day.lead}</p>{/if}
							{#if weather[day.date]}<WeatherCard day={weather[day.date]} />{/if}

							{#if !wide}{@render dayMap(day)}{/if}

							<ol class="stops">
								{#if startStay}{@render homeStop(startStay, 'start')}{/if}
								{#each day.stops as s, i (s.id)}
									{@const p = s.placeId ? byId.get(s.placeId) : undefined}
									{@const n = numberOf.get(s.id)}
									{@const v = visitOf(s)}
									<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions (tapping a card highlights its leg on the map; keyboard users get it from focus) -->
									<li style:animation-delay="{120 + i * 70}ms" id={n ? `parada-${n}` : undefined} class:hot={n != null && hovered === n} class:visited={!!v.visitedAt}
										onmouseenter={() => (hovered = n ?? null)} onmouseleave={() => (hovered = null)} onclick={() => (hovered = n ?? null)} onfocusin={() => (hovered = n ?? null)}>
										<div class="stop card">
											{#if p?.photos[0]}
												<a class="cover" href="/roteiro/lugar/{p.id}" tabindex="-1" aria-hidden="true"><img src={p.photos[0].url} alt="" loading="lazy" /></a>
											{/if}
											<div class="stop-top">
												{#if p?.photos[0]}
													<!-- the photo is the cover above -->
												{:else if p && !admin}
													<span class="thumb empty" style:--c={CATEGORY[p.category].color} aria-hidden="true"><Icon name="pin" size={22} /></span>
												{:else if p}
													<button class="thumb empty" style:--c={CATEGORY[p.category].color} onclick={() => (editingPlace = p)} aria-label="Adicionar foto de {p.name}">
														<Icon name="camera" size={22} /><span>foto</span>
													</button>
												{/if}
												<div class="stop-text">
													<div class="when">
														{#if n}<span class="num" aria-label="Parada {n}">{n}</span>{/if}
														{#if s.time}<span class="time">{s.time}</span>{/if}
													</div>
													<h3>{#if p}<a class="place-link" href="/roteiro/lugar/{p.id}">{p.name}</a>{:else}{s.label}{/if}</h3>
													<span class="badge" style:--c={TRANSPORT[s.transport].color}>{TRANSPORT[s.transport].label}</span>
													{#if p}<span class="badge" style:--c={CATEGORY[p.category].color}>{CATEGORY[p.category].label}</span>{/if}
												</div>
											</div>
											{#if s.note}<p>{s.note}</p>{/if}
											{#if v.visitedAt}<p class="visit-note small"><Icon name="check" size={15} /> Fomos! Marcado por {v.visitedBy === data.me.id ? 'você' : personName(v.visitedBy)} em {fmtWhen(v.visitedAt)}</p>{/if}
											{#if p?.hours}<p class="small muted">Horário: {p.hours}</p>{/if}
											{#if p && (p.price || p.priceLevel != null)}<p class="small muted">Preço: {priceSigns(p.priceLevel)} {p.price}</p>{/if}
											{#if p}
												<div class="stop-actions">
													<button class="btn small visit" class:on={!!v.visitedAt} aria-pressed={!!v.visitedAt} onclick={() => toggleVisit(s)}>
														<Icon name="check" size={18} /> {v.visitedAt ? 'Fomos!' : 'Fomos?'}
													</button>
													<a class="btn small uber" href={uberUrl(p)} target="_blank" rel="noopener"><Icon name="car" size={18} /> Pedir Uber</a>
													<a class="btn small secondary icon" href={placeUrl(p)} target="_blank" rel="noopener" aria-label="Abrir no Google Maps" title="Google Maps"><Icon name="map" size={18} /></a>
													{#if admin}<button class="btn small secondary icon" onclick={() => (editingPlace = p)} aria-label="Editar lugar ({p.name})" title="Editar lugar">✎</button>{/if}
												</div>
											{/if}
										</div>
									</li>
								{:else}
									<li class="empty muted">Nenhuma parada ainda.</li>
								{/each}
								{#if endStay}{@render homeStop(endStay, 'end')}{/if}
							</ol>
							{#if googleRoute && !day.wedding}
								<a class="btn sea block" href={googleRoute} target="_blank" rel="noopener"><Icon name="map" size={20} /> Rota do dia no Google Maps</a>
							{/if}
							{#if admin}<button class="btn secondary block edit" onclick={() => (editingDay = 'current')}>✎ Editar este dia</button>{/if}
						{/if}
					</div>
				</article>
			{/key}
		{:else}
			<div class="card empty-card"><p>O roteiro ainda está vazio.</p>{#if admin}<button class="btn sun" onclick={() => (editingDay = 'new')}>Criar o primeiro dia</button>{/if}</div>
		{/if}
		</div>
		{#if wide && editingDay !== 'new' && day && mapPoints.length}
			<aside class="map-side" aria-label="Mapa do dia">{@render dayMap(day)}</aside>
		{/if}
		</div>
	{:else if tab === 'hospedagem'}
		<section class="stays-tab">
			<p class="muted intro">
				O dia a dia de cada pessoa começa e termina onde ela está hospedada.
				{#if !data.me.isAdmin}Só administradores mudam a hospedagem.{/if}
			</p>
			{#if data.me.isAdmin && data.stays.length}
				<button class="btn sun add-stay" onclick={() => (editingStay = 'new')}>＋ Hospedagem</button>
				{#if homeless.length}<p class="small warn">Sem hospedagem: {homeless.map((p) => p.name).join(', ')}</p>{/if}
			{/if}
			<div class="stays">
				{#each data.stays as st (st.id)}
					{@const mine = st.guests.includes(data.me.id)}
					<article class="card stay" class:mine>
						<header>
							<span class="stay-ico" aria-hidden="true">{STAY_KIND[st.kind].emoji}</span>
							<div>
								<h3>{st.name}</h3>
								<span class="badge" style:--c="var(--sea)">{STAY_KIND[st.kind].label}</span>
								{#if mine}<span class="badge" style:--c="var(--leaf)">Você fica aqui</span>{/if}
							</div>
						</header>
						<p class="dates small">
							<span><b>Chegada</b> {st.checkIn ? fmtDay(st.checkIn) : 'início da viagem'}</span>
							<span><b>Saída</b> {st.checkOut ? fmtDay(st.checkOut) : 'fim da viagem'}</span>
						</p>
						{#if st.address}<p class="small muted">{st.address}</p>{/if}
						<ul class="guests" aria-label="Quem fica aqui">
							{#each st.guests as g (g)}
								{@const p = personOf(g)}
								{#if p}
									<li style:--c={p.color}>
										{#if p.photo}<img src={p.photo} alt="" />{:else}<span class="ini" aria-hidden="true">{p.name.slice(0, 1)}</span>{/if}
										{p.name}
									</li>
								{/if}
							{:else}
								<li class="muted">Ninguém ainda</li>
							{/each}
						</ul>
						{#if st.note}<p class="small">{st.note}</p>{/if}
						<div class="stop-actions">
							<a class="btn small uber" href={uberUrl(st)} target="_blank" rel="noopener"><Icon name="car" size={18} /> Pedir Uber</a>
							<a class="btn small secondary icon" href={placeUrl(st)} target="_blank" rel="noopener" aria-label="Abrir no Google Maps" title="Google Maps"><Icon name="map" size={18} /></a>
							{#if st.link}<a class="btn small secondary" href={st.link} target="_blank" rel="noopener">Reserva</a>{/if}
							{#if data.me.isAdmin}<button class="btn small secondary icon" onclick={() => (editingStay = st)} aria-label="Editar {st.name}" title="Editar">✎</button>{/if}
						</div>
					</article>
				{:else}
					<div class="card empty-card">
						<p>Nenhuma hospedagem cadastrada ainda.</p>
						{#if data.me.isAdmin}<button class="btn sun" onclick={() => (editingStay = 'new')}>Cadastrar hotel ou Airbnb</button>{/if}
					</div>
				{/each}
			</div>
		</section>
	{:else}
		<div class="place-tools">
			<div class="chips" role="group" aria-label="Tipo de lugar">
				<button class="chip" aria-pressed={filter === 'todos'} onclick={() => (filter = 'todos')}>Todos</button>
				{#each Object.entries(CATEGORY) as [k, c]}
					<button class="chip" aria-pressed={filter === k} onclick={() => (filter = k as PlaceCategory)}>{c.plural}</button>
				{/each}
			</div>
			<div class="search-row">
				<label class="search"><Icon name="search" size={18} /><span class="sr-only">Procurar nos lugares</span><input type="search" bind:value={query} placeholder="Procurar" /></label>
				{#if admin}<button class="btn sun small" onclick={() => (editingPlace = 'new')}>＋ Lugar</button>{/if}
			</div>
		</div>
		{#if toast}<p class="toast" role="status">{toast}</p>{/if}
		<div class="places">
			{#each shown as p (p.id)}
				<PlaceCard place={p} visited={visitedPlaces.has(p.id)} usedOn={usedOn.get(p.id) ?? []} days={data.days} onedit={admin ? () => (editingPlace = p) : undefined} onadd={admin ? (date) => addToDay(p, date) : undefined} />
			{:else}
				<p class="muted">Nenhum lugar {query ? 'com esse nome' : 'aqui ainda'}.</p>
			{/each}
		</div>
	{/if}
</main>

{#if editingStay}
	<StayEditor
		stay={editingStay === 'new' ? null : editingStay}
		persons={data.persons}
		firstDay={data.days[0]?.date ?? today}
		lastDay={data.days.at(-1)?.date ?? today}
		onclose={() => (editingStay = null)}
		onsaved={reload}
	/>
{/if}

{#if editingPlace}
	<PlaceEditor place={editingPlace === 'new' ? null : editingPlace} onclose={() => (editingPlace = null)} onsaved={reload} />
{/if}

<style>
	.roteiro { max-width: 1280px; }
	.roteiro > .tabs { max-width: 720px; margin-inline: auto; }
	.day-layout { display: grid; grid-template-columns: minmax(0, 1fr); gap: 20px; align-items: start; max-width: 720px; margin-inline: auto; }
	.day-layout.with-map { grid-template-columns: minmax(0, 1fr) minmax(0, 1.15fr); max-width: none; }
	/* editing: more room for the form, the map stays beside it */
	.day-layout.with-map.editing { grid-template-columns: minmax(0, 1.6fr) minmax(0, 1fr); }
	.map-side { position: sticky; top: calc(76px + env(safe-area-inset-top)); }
	.stops li.hot .stop { border-color: var(--sun); }
	.tabs { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 6px; padding: 5px; margin: 6px 0 12px; background: var(--surface); border: 2.5px solid var(--line); border-radius: 999px; }
	.tabs button { display: inline-flex; justify-content: center; align-items: center; gap: 6px; min-height: 42px; border: 0; border-radius: 999px; background: none; color: var(--muted); font: 600 1rem var(--font-display); cursor: pointer; }
	.tabs button[aria-selected='true'] { background: var(--sea); color: #fff; box-shadow: 0 3px 0 var(--sea-dark); }

	/* centered when they fit; still scrolls sideways on small phones */
	.days { margin: 8px auto 14px; width: fit-content; max-width: 100%; }
	.daybtn { display: grid; justify-items: center; line-height: 1.15; min-width: 56px; padding: 6px 10px; border-style: dashed; }
	.daybtn span { font-size: 0.75rem; }
	.daybtn.today { position: relative; }
	.daybtn.today::after { content: 'hoje'; position: absolute; top: -9px; right: -6px; font-size: 0.6rem; background: var(--coral); color: #fff; border-radius: 999px; padding: 0 5px; }
	.daybtn.wedding:not([aria-selected='true']) { border-color: var(--berry); color: var(--berry); }
	.daybtn.add { color: var(--sea); border-color: var(--sea); }
	.daybtn .wx { display: grid; place-items: center; opacity: 0.85; margin-top: 1px; }
	.place-link { color: inherit; text-decoration: none; }
	.place-link:hover, .place-link:focus-visible { text-decoration: underline; }
	.place-link::after { content: ' ›'; color: var(--sea); }

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
	.ticket-body > h2 { margin: 0 0 12px; }
	.who { display: flex; gap: 6px; align-items: center; color: var(--muted); font-weight: 700; }
	.lead { font-size: 1.05rem; }
	.legend { display: flex; flex-wrap: wrap; gap: 12px; }
	.legend span { display: inline-flex; align-items: center; gap: 5px; }
	.legend i { width: 18px; height: 4px; border-radius: 2px; background: var(--c); }
	.stops { list-style: none; padding: 0; margin: 16px 0; display: grid; gap: 14px; }
	.stops li { animation: pop-in 0.45s var(--bounce) both; scroll-margin: 90px; }
	.stops li.empty { display: block; }
	.when { display: flex; align-items: center; gap: 6px; margin-bottom: 4px; }
	.time {
		font: 600 0.85rem var(--font-display); background: var(--sun); color: #4a3410;
		border-radius: 10px; padding: 2px 10px; box-shadow: 0 2px 0 var(--sun-dark);
	}
	.stop { padding: 12px 14px; box-shadow: 0 3px 0 var(--shadow); overflow: hidden; }
	/* the place's photo across the top of the card */
	.cover { display: block; margin: -12px -14px 12px; aspect-ratio: 16 / 9; max-height: 240px; width: calc(100% + 28px); border-bottom: 2px solid var(--line); background: var(--surface-2); }
	.cover img { display: block; width: 100%; height: 100%; object-fit: cover; transition: transform 0.3s; }
	.cover:hover img { transform: scale(1.03); }
	.stop p { margin: 6px 0 0; }
	.stop-top { display: flex; gap: 10px; align-items: flex-start; }
	.thumb { flex: none; width: 76px; height: 76px; border-radius: 14px; object-fit: cover; border: 2px solid var(--line); }
	.thumb.empty {
		display: grid; place-content: center; justify-items: center; gap: 2px; padding: 0; cursor: pointer;
		background: color-mix(in srgb, var(--c) 22%, var(--surface-2)); color: var(--c); border-style: dashed; font-weight: 800; font-size: 0.72rem;
	}
	.stop-text { min-width: 0; }
	.btn.visit { --b: var(--surface-2); --b-dark: var(--shadow); --b-ink: var(--ink); border: 2px dashed var(--leaf); }
	.btn.visit.on { --b: var(--leaf); --b-dark: var(--leaf-dark); --b-ink: var(--on-leaf); border-style: solid; }
	.stops li.visited .stop { border-color: var(--leaf); }
	.stops li.visited .time { background: var(--leaf); color: var(--on-leaf); box-shadow: 0 2px 0 var(--leaf-dark); }
	.visit-note { display: flex; align-items: center; gap: 4px; color: var(--leaf); font-weight: 800; }
	h3 { margin: 0 0 6px; }
	.num { flex: none; display: grid; place-items: center; width: 24px; height: 24px; border-radius: 50%; background: var(--sun); color: #4a3410; font-size: 0.8rem; }
	.badge { display: inline-block; border: 2px solid var(--c); color: var(--c); border-radius: 999px; padding: 0 10px; font-size: 0.8rem; font-weight: 800; margin: 0 4px 4px 0; }
	.stop-actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 10px; }
	@media (max-width: 520px) {
		/* Uber, map and edit on one line; "Fomos?" below, full width */
		.stop-actions .visit { order: 1; width: 100%; }
	}
	.btn.icon { width: 44px; min-height: 44px; padding: 0; font-size: 1.1rem; }
	.btn.uber { --b: #1b1b1b; --b-dark: #000; --b-ink: #fff; }
	.edit { margin-top: 10px; }
	.empty-card { display: grid; gap: 12px; justify-items: center; text-align: center; padding: 24px; }
	.empty-card p { margin: 0; }

	.place-tools { display: grid; gap: 10px; margin-bottom: 14px; }
	.search-row { display: flex; gap: 10px; align-items: center; }
	.search { flex: 1; display: flex; align-items: center; gap: 8px; padding: 0 12px; min-height: 44px; background: var(--surface); border: 2.5px solid var(--line); border-radius: 14px; color: var(--muted); }
	.search:focus-within { border-color: var(--sea); }
	.search input { flex: 1; min-width: 0; border: 0; background: none; color: var(--ink); font: inherit; outline: none; padding: 8px 0; }
	.places { display: grid; gap: 18px; }
	@media (min-width: 640px) { .places { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
	@media (min-width: 1000px) {
		.places { grid-template-columns: repeat(3, minmax(0, 1fr)); }
		.place-tools { grid-template-columns: auto 1fr; align-items: center; }
		.place-tools .chips { flex-wrap: wrap; }
	}
	@media (max-width: 420px) { .tabs button { font-size: 0.88rem; gap: 4px; } .tabs button :global(svg) { display: none; } }
	.home-stop .stop.home { border-style: dashed; border-color: var(--sea); }
	.home-ico { display: grid; place-items: center; font-size: 2rem; background: color-mix(in srgb, var(--sea) 22%, var(--surface-2)); }
	.home-stop .time { display: inline-flex; align-items: center; gap: 4px; background: var(--sea); color: #fff; box-shadow: 0 2px 0 var(--sea-dark); }
	.home-stop h3 { margin-bottom: 2px; }
	.home-stop .stop-text p { margin: 0; }
	.stays-tab { max-width: 1000px; margin-inline: auto; display: grid; gap: 12px; }
	/* the empty state (and a single stay) sit in the middle, under the tabs */
	.stays > .empty-card { grid-column: 1 / -1; justify-self: center; width: min(100%, 520px); }
	@media (min-width: 760px) { .stays > .stay:only-child { grid-column: 1 / -1; justify-self: center; width: min(100%, 520px); } }
	.intro { margin: 0; text-align: center; }
	.add-stay { justify-self: center; }
	.warn { margin: 0; text-align: center; color: var(--coral); font-weight: 800; }
	.stays { display: grid; gap: 18px; }
	@media (min-width: 760px) { .stays { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
	.stay { display: grid; gap: 8px; align-content: start; }
	.stay.mine { border-color: var(--leaf); }
	.stay header { display: flex; gap: 12px; align-items: center; }
	.stay h3 { margin: 0 0 4px; }
	.stay p { margin: 0; }
	.stay-ico { flex: none; display: grid; place-items: center; width: 56px; height: 56px; border-radius: 14px; font-size: 1.9rem; background: color-mix(in srgb, var(--sea) 22%, var(--surface-2)); }
	.dates { display: flex; flex-wrap: wrap; gap: 6px 16px; }
	.guests { list-style: none; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: 6px; }
	.guests li { display: inline-flex; align-items: center; gap: 6px; padding: 2px 10px 2px 2px; border-radius: 999px; background: var(--surface-2); font-weight: 800; font-size: 0.9rem; }
	.guests li.muted { padding: 2px 10px; font-weight: 600; }
	.guests img, .guests .ini { width: 26px; height: 26px; border-radius: 50%; object-fit: cover; }
	.guests .ini { display: grid; place-items: center; background: var(--c); color: #fff; font-size: 0.8rem; }
	.toast { position: sticky; top: 76px; z-index: 6; margin: 0 0 12px; padding: 10px 14px; border-radius: 14px; background: var(--leaf); color: #fff; font-weight: 800; animation: pop-in 0.3s var(--bounce); }
</style>
