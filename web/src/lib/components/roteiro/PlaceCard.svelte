<script lang="ts">
	import Icon from '$lib/components/Icon.svelte';
	import { CATEGORY, placeUrl, priceSigns, uberUrl, type RoteiroPlace } from '$lib/itinerary';
	import { dayKeyLabel } from '$lib/format';

	let {
		place,
		usedOn = [],
		visited = false,
		days = [],
		onedit,
		onadd
	}: {
		place: RoteiroPlace;
		/** dates of the days whose roteiro includes this place */
		usedOn?: string[];
		/** someone ticked "Fomos!" on a stop with this place */
		visited?: boolean;
		/** all days, for "Pôr no roteiro" */
		days?: { date: string; title: string }[];
		/** admins only (left out for everyone else) */
		onedit?: () => void;
		onadd?: (date: string) => void;
	} = $props();

	let photo = $state(0);
	let track = $state<HTMLDivElement>();
	const cat = $derived(CATEGORY[place.category]);
	const signs = $derived(priceSigns(place.priceLevel));
	let adding = $state('');

	function onScroll() {
		if (track) photo = Math.round(track.scrollLeft / track.clientWidth);
	}
	const linkLabel = $derived.by(() => {
		try {
			const h = new URL(place.link).hostname.replace(/^www\./, '');
			return h.includes('instagram') ? 'Instagram' : h;
		} catch {
			return 'Site';
		}
	});
</script>

<article class="place card">
	<div class="photos" class:empty={!place.photos.length}>
		{#if place.photos.length}
			<div class="track" bind:this={track} onscroll={onScroll}>
				{#each place.photos as ph, i (ph.id)}
					<img src={ph.url} alt={i === 0 ? place.name : ''} loading="lazy" draggable="false" />
				{/each}
			</div>
			{#if place.photos.length > 1}
				<span class="dots" aria-hidden="true">{#each place.photos as ph, i (ph.id)}<i class:on={i === photo}></i>{/each}</span>
			{/if}
		{:else}
			{#if onedit}
				<button class="add-photo" onclick={onedit}><Icon name="camera" size={26} /><span>Adicionar fotos</span></button>
			{:else}
				<span class="add-photo" aria-hidden="true" style:cursor="default"><Icon name="camera" size={26} /><span>Sem fotos ainda</span></span>
			{/if}
		{/if}
		<span class="cat" style:--c={cat.color}>{cat.label}</span>
		{#if visited}<span class="been"><Icon name="check" size={14} /> Fomos!</span>{/if}
	</div>

	<div class="body">
		<h3><a class="name" href="/roteiro/lugar/{place.id}">{place.name}</a></h3>
		{#if place.address}<p class="small muted addr"><Icon name="pin" size={14} /> {place.address}</p>{/if}
		<dl>
			{#if place.hours}<div><dt>Horário</dt><dd>{place.hours}</dd></div>{/if}
			{#if place.price || signs}<div><dt>Preço</dt><dd>{#if signs}<strong class="signs">{signs}</strong>{/if} {place.price}</dd></div>{/if}
		</dl>
		{#if place.description}<p class="desc">{place.description}</p>{/if}
		{#if usedOn.length}
			<p class="used small">
				<Icon name="ticket" size={14} /> No roteiro:
				{#each usedOn as d, i}{@const l = dayKeyLabel(d)}{i ? ', ' : ' '}<strong>{l.weekday} {l.day}</strong>{/each}
			</p>
		{/if}

		<div class="actions">
			<a class="btn small sea" href="/roteiro/lugar/{place.id}">Ver detalhes</a>
			<a class="btn small uber" href={uberUrl(place)} target="_blank" rel="noopener"><Icon name="car" size={18} /> Pedir Uber</a>
			<a class="btn small secondary" href={placeUrl(place)} target="_blank" rel="noopener"><Icon name="map" size={18} /> Google Maps</a>
			{#if place.link}<a class="btn small secondary" href={place.link} target="_blank" rel="noopener"><Icon name="expand" size={16} /> {linkLabel}</a>{/if}
		</div>
		{#if onadd && onedit}
		<div class="foot">
			<label class="sr-only" for="add-{place.id}">Pôr no roteiro</label>
			<select id="add-{place.id}" class="add" bind:value={adding} onchange={() => { if (adding) { onadd?.(adding); adding = ''; } }}>
				<option value="">+ Pôr no roteiro…</option>
				{#each days as d}{@const l = dayKeyLabel(d.date)}<option value={d.date}>{l.weekday} {l.day} · {d.title}</option>{/each}
			</select>
			<button class="link" onclick={onedit}>Editar</button>
		</div>
		{/if}
	</div>
</article>

<style>
	.place { padding: 0; overflow: hidden; display: grid; grid-template-columns: minmax(0, 1fr); min-width: 0; animation: pop-in 0.4s var(--bounce) both; }
	.photos { position: relative; aspect-ratio: 16 / 10; background: var(--surface-2); border-bottom: 2.5px solid var(--line); }
	.track { display: flex; height: 100%; overflow-x: auto; scroll-snap-type: x mandatory; scrollbar-width: none; }
	.track::-webkit-scrollbar { display: none; }
	.track img { flex: 0 0 100%; width: 100%; height: 100%; object-fit: cover; scroll-snap-align: center; }
	.dots { position: absolute; bottom: 8px; left: 50%; translate: -50% 0; display: flex; gap: 5px; }
	.dots i { width: 7px; height: 7px; border-radius: 50%; background: rgb(255 255 255 / 0.55); }
	.dots i.on { background: #fff; transform: scale(1.25); }
	.add-photo {
		position: absolute; inset: 0; display: grid; place-content: center; justify-items: center; gap: 6px; width: 100%;
		border: 0; background: repeating-linear-gradient(135deg, transparent 0 14px, rgb(255 255 255 / 0.03) 14px 28px); color: var(--muted);
		font-weight: 800; cursor: pointer;
	}
	.cat {
		position: absolute; top: 10px; left: 10px; padding: 2px 10px; border-radius: 999px; font-size: 0.78rem; font-weight: 800;
		background: var(--c); color: #fff; box-shadow: 0 2px 0 rgb(0 0 0 / 0.25);
	}
	.been {
		position: absolute; top: 10px; right: 10px; display: inline-flex; align-items: center; gap: 3px; padding: 2px 10px;
		border-radius: 999px; font-size: 0.78rem; font-weight: 800; background: var(--leaf); color: var(--on-leaf); box-shadow: 0 2px 0 rgb(0 0 0 / 0.25);
	}
	.body { padding: 12px 14px 14px; display: grid; grid-template-columns: minmax(0, 1fr); gap: 6px; }
	h3 { margin: 0; }
	.addr { display: flex; gap: 4px; align-items: flex-start; margin: 0; }
	.addr :global(svg) { flex: none; margin-top: 3px; }
	dl { margin: 0; display: grid; gap: 4px; }
	dl div { display: grid; grid-template-columns: 64px 1fr; gap: 8px; }
	dt { font-weight: 800; color: var(--muted); font-size: 0.85rem; padding-top: 1px; }
	dd { margin: 0; }
	.signs { color: var(--sun); letter-spacing: 0.05em; }
	.desc { margin: 2px 0 0; white-space: pre-wrap; display: -webkit-box; -webkit-line-clamp: 3; line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
	.name { color: inherit; text-decoration: none; }
	.name:hover, .name:focus-visible { text-decoration: underline; }
	.used { margin: 0; display: flex; flex-wrap: wrap; gap: 4px; align-items: center; color: var(--leaf); }
	.actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 6px; }
	.btn.uber { --b: #1b1b1b; --b-dark: #000; --b-ink: #fff; }
	.foot { display: flex; align-items: center; gap: 10px; margin-top: 4px; }
	.add { flex: 1; width: auto; min-width: 0; padding: 8px 12px; font-size: 0.9rem; }
	.foot .link { flex: none; }
	.link { background: none; border: 0; color: var(--sea); font-weight: 800; cursor: pointer; min-height: 44px; padding: 0 6px; }
</style>
