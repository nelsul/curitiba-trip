<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import type { Map as MLMap, Marker, IControl } from 'maplibre-gl';
	import MapView from '$lib/components/MapView.svelte';
	import Filters from '$lib/components/Filters.svelte';
	import Icon, { ICONS } from '$lib/components/Icon.svelte';
	import { dayKey, fmtAgo, fmtDateTime } from '$lib/format';
	import { currentPosition, loc, startSharing, stopSharing } from '$lib/location.svelte';
	import { animateIn, personElement, pinElement, polaroidElement } from '$lib/map-markers';
	import { TRIP_DAYS } from '$lib/trip';

	let { data } = $props();

	type ML = typeof import('maplibre-gl');
	let map = $state<MLMap | null>(null);
	let ml: ML | null = null;
	let markers: Marker[] = [];
	const seen = new Set<string>();
	let latest = $state<typeof data.latest>([]);
	$effect(() => {
		latest = data.latest;
	});

	const today = dayKey(Date.now());
	const initialDay = TRIP_DAYS.includes(today) ? today : 'all';
	let day = $state(initialDay);
	let person = $state('all');
	let showFilters = $state(false);

	const foco = page.url.searchParams.get('foco')?.split(',').map(Number);
	const hasFoco = foco?.length === 2 && foco.every(Number.isFinite);

	const byId = $derived(new Map(data.persons.map((p) => [p.id, p])));
	const days = $derived([...new Set([...TRIP_DAYS, ...data.items.map((i) => i.day)])].sort());
	const visible = (d: string, u: string) => (day === 'all' || d === day) && (person === 'all' || u === person);

	function render(fit: boolean) {
		if (!map || !ml) return;
		for (const m of markers) m.remove();
		markers = [];
		const bounds = new ml.LngLatBounds();
		let stagger = 0;
		const enter = (key: string, node: HTMLElement) => {
			if (seen.has(key)) return;
			seen.add(key);
			animateIn(node, Math.min(stagger++, 12) * 60);
		};

		for (const it of data.items) {
			if (!visible(it.day, it.userId)) continue;
			const p = byId.get(it.userId);
			const color = p?.color ?? '#888';
			let node: HTMLElement;
			let anchor: 'center' | 'bottom' = 'bottom';
			if (it.type === 'media') {
				node = polaroidElement({
					id: it.id,
					href: `/m/${it.id}`,
					thumb: it.thumb,
					color,
					video: it.kind === 'video',
					label: `${it.kind === 'video' ? 'Vídeo' : 'Foto'} de ${p?.name ?? ''}, ${fmtDateTime(it.at)}`
				});
				anchor = 'center';
			} else {
				node = pinElement(color, { href: `/c/${it.id}`, label: `Check-in de ${p?.name ?? ''}, ${fmtDateTime(it.at)}` });
			}
			enter(it.id, node);
			markers.push(new ml.Marker({ element: node, anchor }).setLngLat([it.lng!, it.lat!]).addTo(map));
			bounds.extend([it.lng!, it.lat!]);
		}

		for (const l of latest) {
			if (person !== 'all' && l.userId !== person) continue;
			const node = personElement({ name: l.name, color: l.color, photo: l.photo, ago: fmtAgo(l.at), fresh: Date.now() - Date.parse(l.at) < 15 * 60_000 });
			markers.push(new ml.Marker({ element: node, anchor: 'bottom' }).setLngLat([l.lng, l.lat]).addTo(map));
			if (day === 'all' || day === today) bounds.extend([l.lng, l.lat]);
		}

		if (fit && !bounds.isEmpty()) map.fitBounds(bounds, { padding: 70, maxZoom: 15, duration: 800 });
	}

	// ---- where am I ----
	let me: Marker | null = null;
	let locating = $state(false);

	/** Flies to my position and marks it with a pulsing dot (also works without "Compartilhar local"). */
	async function goToMe() {
		if (!map || !ml || locating) return;
		locating = true;
		loc.error = '';
		try {
			const p = await currentPosition(30_000);
			if (!me) {
				const el = document.createElement('div');
				el.className = 'me-dot';
				el.setAttribute('aria-label', 'Você está aqui');
				me = new ml.Marker({ element: el }).setLngLat([p.lng, p.lat]).addTo(map);
			} else me.setLngLat([p.lng, p.lat]);
			map.flyTo({ center: [p.lng, p.lat], zoom: Math.max(map.getZoom(), 15), duration: 1000 });
		} catch (e) {
			loc.error = (e as Error).message;
		} finally {
			locating = false;
		}
	}
	// keep the dot where I am while sharing
	$effect(() => {
		if (me && loc.pos) me.setLngLat([loc.pos.lng, loc.pos.lat]);
	});

	/** A map button under the zoom buttons, styled like them. */
	class LocateControl implements IControl {
		#el: HTMLDivElement | undefined;
		onAdd() {
			this.#el = document.createElement('div');
			this.#el.className = 'maplibregl-ctrl maplibregl-ctrl-group';
			const b = document.createElement('button');
			b.type = 'button';
			b.className = 'locate';
			b.title = 'Ir para onde estou';
			b.setAttribute('aria-label', 'Ir para onde estou');
			b.innerHTML = `<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${ICONS.locate}"/></svg>`;
			b.onclick = goToMe;
			this.#el.append(b);
			return this.#el;
		}
		onRemove() {
			this.#el?.remove();
		}
	}

	function ready(m: MLMap, lib: ML) {
		ml = lib;
		m.addControl(new LocateControl(), 'top-right');
		map = m;
		render(!hasFoco);
	}

	let lastFilter = `${initialDay}|all`; // first render (in ready) decides the initial fit
	$effect(() => {
		const key = `${day}|${person}`;
		void data;
		void latest;
		if (!map) return;
		render(key !== lastFilter);
		lastFilter = key;
	});

	onMount(() => {
		const t = setInterval(async () => {
			if (document.visibilityState !== 'visible') return;
			try {
				const r = await fetch('/api/locations');
				if (r.ok) latest = await r.json();
			} catch {}
		}, 20_000);
		return () => clearInterval(t);
	});

	// ---- check-in ----
	let dialog: HTMLDialogElement;
	let note = $state('');
	let busy = $state(false);
	let checkinError = $state('');
	let stamp = $state(false);

	async function doCheckin(e: SubmitEvent) {
		e.preventDefault();
		busy = true;
		checkinError = '';
		try {
			const p = await currentPosition(30_000);
			const r = await fetch('/api/checkins', {
				method: 'POST',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify({ lat: p.lat, lng: p.lng, accuracy: p.accuracy, note })
			});
			if (!r.ok) throw new Error('Não foi possível salvar o check-in.');
			const { id } = await r.json();
			// picture of the map for the diary; runs in the background, the feed falls back to a banner meanwhile
			import('$lib/map-snapshot').then(({ attachSnapshot }) =>
				attachSnapshot(id, { lat: p.lat, lng: p.lng, color: data.me.color, name: data.me.name, photo: data.me.photo, at: Date.now() }).then(
					() => invalidate('app:feed')
				)
			);
			note = '';
			dialog.close();
			if (day !== 'all' && day !== today) day = today;
			map?.flyTo({ center: [p.lng, p.lat], zoom: 16, duration: 1200 });
			await invalidate('app:feed'); // new pin drops in on render
			stamp = true;
			setTimeout(() => (stamp = false), 2600);
		} catch (err) {
			checkinError = (err as Error).message;
		} finally {
			busy = false;
		}
	}
</script>

<svelte:head><title>Mapa · Viagem a Curitiba</title></svelte:head>

<main class="wrap">
	<div class="frame">
		<MapView center={hasFoco ? [foco![1], foco![0]] : undefined} zoom={hasFoco ? 16 : 12} framed onready={ready} />
	</div>

	<div class="overlay">
		<button class="btn small secondary" onclick={() => (showFilters = !showFilters)} aria-expanded={showFilters}>
			<Icon name="calendar" size={18} /> Filtros{day !== 'all' || person !== 'all' ? ' •' : ''}
		</button>
		{#if showFilters}
			<div class="card panel pop-in"><Filters {days} persons={data.persons} bind:day bind:person /></div>
		{/if}
	</div>

	{#if stamp}
		<div class="stamp-toast" role="status"><span>Check-in<br /><small>{fmtDateTime(Date.now())}</small></span></div>
	{/if}

	<div class="actions">
		{#if loc.error}<p class="card small error">{loc.error}</p>{/if}
		<button class="btn" class:secondary={!loc.sharing} onclick={() => (loc.sharing ? stopSharing() : startSharing())}>
			{#if loc.sharing}<span class="live-dot"></span> Compartilhando{:else}<Icon name="people" size={20} /> Compartilhar local{/if}
		</button>
		<button class="btn sun" onclick={() => dialog.showModal()}><Icon name="pin" size={20} /> Check-in</button>
	</div>
</main>

<dialog bind:this={dialog} class="card">
	<form onsubmit={doCheckin}>
		<div class="title-row"><span class="title-icon"><Icon name="pin" size={24} /></span><h2>Check-in</h2></div>
		<p class="muted small">Crava um alfinete onde você está agora, no mapa e no diário de todo mundo.</p>
		<label for="note" class="sr-only">Comentário</label>
		<textarea id="note" bind:value={note} placeholder="O que está rolando? (opcional)" rows="3"></textarea>
		{#if checkinError}<p class="error small">{checkinError}</p>{/if}
		<div class="row">
			<button type="button" class="btn secondary" onclick={() => dialog.close()}>Cancelar</button>
			<button class="btn sun" disabled={busy}>{busy ? 'Localizando…' : 'Fazer check-in'}</button>
		</div>
	</form>
</dialog>

<style>
	.wrap {
		position: relative;
		height: calc(100dvh - 64px - env(safe-area-inset-top) - var(--nav-h) - 10px - env(safe-area-inset-bottom));
		padding: 10px;
	}
	.frame { height: 100%; }
	.overlay { position: absolute; z-index: 5; top: 22px; left: 22px; right: 70px; display: grid; gap: 8px; justify-items: start; }
	.overlay .btn { background: var(--surface); }
	.panel { max-width: 100%; padding: 6px 12px; }
	.actions { position: absolute; z-index: 5; left: 22px; right: 22px; bottom: 26px; display: flex; flex-wrap: wrap; gap: 10px; justify-content: center; }
	.actions .btn.secondary { background: var(--surface); }
	.actions p { width: 100%; margin: 0; padding: 8px 12px; }
	.wrap :global(.locate) { display: grid; place-items: center; color: var(--ink); }
	.wrap :global(.locate:disabled) { opacity: 0.5; }
	.wrap :global(.me-dot) {
		width: 18px; height: 18px; border-radius: 50%; background: #3b8cff; border: 3px solid #fff;
		box-shadow: 0 0 0 0 rgb(59 140 255 / 0.6); animation: me-pulse 2s infinite;
	}
	@keyframes me-pulse { 70% { box-shadow: 0 0 0 16px rgb(59 140 255 / 0); } 100% { box-shadow: 0 0 0 0 rgb(59 140 255 / 0); } }
	.live-dot { width: 10px; height: 10px; border-radius: 50%; background: currentColor; animation: bob 1s infinite; }
	.stamp-toast {
		position: absolute; z-index: 6; top: 34%; left: 50%; margin-left: -80px; width: 160px; height: 160px; display: grid; place-items: center; pointer-events: none;
	}
	.stamp-toast span {
		display: grid; place-items: center; width: 150px; height: 150px; border-radius: 50%; text-align: center;
		border: 5px double var(--coral); color: var(--coral); background: rgb(255 252 240 / 0.88);
		font: 600 1.5rem/1.1 var(--font-display); text-transform: uppercase; letter-spacing: 0.05em;
		animation: stamp-in 0.55s var(--bounce) both;
	}
	.stamp-toast small { font-size: 0.75rem; letter-spacing: 0; }
	dialog { border: 2.5px solid var(--line); width: min(420px, calc(100vw - 32px)); color: var(--ink); }
	dialog[open] { animation: pop-in 0.35s var(--bounce); }
	dialog::backdrop { background: rgb(40 30 20 / 0.45); }
	dialog form { display: grid; gap: 10px; }
	dialog h2 { margin: 0; }
	dialog p { margin: 0; }
	.row { display: flex; gap: 8px; justify-content: flex-end; flex-wrap: wrap; }
</style>
