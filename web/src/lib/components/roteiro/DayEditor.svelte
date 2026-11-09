<script lang="ts">
	import Icon from '$lib/components/Icon.svelte';
	import PlaceEditor from './PlaceEditor.svelte';
	import { CATEGORY, TRANSPORT, inputToTime, timeToInput, type PlaceCategory, type RoteiroDay, type RoteiroPlace, type Transport } from '$lib/itinerary';
	import { api } from '$lib/roteiro-client';

	let {
		day,
		places,
		takenDates,
		suggestedDate,
		onclose,
		onsaved,
		onplaceschanged
	}: {
		/** null = new day */
		day: RoteiroDay | null;
		places: RoteiroPlace[];
		/** dates that already have a day (a new day can't reuse them) */
		takenDates: string[];
		suggestedDate: string;
		onclose: () => void;
		onsaved: (date: string | null) => void;
		onplaceschanged: () => void;
	} = $props();

	type EditStop = { key: number; id?: string; time: string; clock: boolean; placeId: string; label: string; transport: Transport; note: string };
	let seq = 0;
	const toEdit = (s: { id: string; time: string; placeId: string | null; label: string; transport: Transport; note: string }): EditStop => {
		const t = timeToInput(s.time);
		return { key: seq++, id: s.id, time: t || s.time, clock: !!t || !s.time, placeId: s.placeId ?? '', label: s.label, transport: s.transport, note: s.note };
	};

	// svelte-ignore state_referenced_locally
	const d0 = day;
	// svelte-ignore state_referenced_locally
	let date = $state(d0?.date ?? suggestedDate);
	let title = $state(d0?.title ?? '');
	let who = $state(d0?.who ?? '');
	let lead = $state(d0?.lead ?? '');
	let wedding = $state(d0?.wedding ?? false);
	let stops = $state<EditStop[]>(d0?.stops.map(toEdit) ?? []);
	let busy = $state(false);
	let error = $state('');
	/** stop waiting for a new place from the place editor */
	let creatingFor = $state<number | null>(null);

	const grouped = $derived(
		(Object.keys(CATEGORY) as PlaceCategory[]).map((c) => [c, places.filter((p) => p.category === c)] as const).filter(([, l]) => l.length)
	);

	function add() {
		stops = [...stops, { key: seq++, time: '', clock: true, placeId: '', label: '', transport: stops.length ? 'uber' : 'pe', note: '' }];
	}
	function move(i: number, by: number) {
		const j = i + by;
		if (j < 0 || j >= stops.length) return;
		const next = [...stops];
		[next[i], next[j]] = [next[j], next[i]];
		stops = next;
	}
	function removeStop(i: number) {
		stops = stops.filter((_, k) => k !== i);
	}
	function placeChanged(s: EditStop) {
		if (s.placeId === '__new') {
			s.placeId = '';
			creatingFor = s.key;
		}
	}

	async function save(e: SubmitEvent) {
		e.preventDefault();
		error = '';
		if (!d0 && takenDates.includes(date)) {
			error = 'Esse dia já existe no roteiro. Escolha outra data ou edite o dia.';
			return;
		}
		busy = true;
		try {
			await api('PUT', `/api/roteiro/days/${date}`, {
				title, who, lead, wedding,
				stops: stops.map((s) => ({
					id: s.id,
					time: s.clock ? inputToTime(s.time) : s.time.trim(),
					placeId: s.placeId || null,
					label: s.placeId ? '' : s.label,
					transport: s.transport,
					note: s.note
				}))
			});
			onsaved(date);
		} catch (err) {
			error = (err as Error).message;
		} finally {
			busy = false;
		}
	}

	async function removeDay() {
		if (!d0 || !confirm('Apagar este dia do roteiro para todo mundo?')) return;
		busy = true;
		try {
			await api('DELETE', `/api/roteiro/days/${d0.date}`);
			onsaved(null);
		} catch (err) {
			error = (err as Error).message;
			busy = false;
		}
	}
</script>

<form class="day-editor" onsubmit={save}>
	<div class="head-fields">
		{#if !d0}
			<label><span class="label">Data</span><input type="date" bind:value={date} required /></label>
		{/if}
		<label><span class="label">Título do dia</span><input type="text" bind:value={title} maxlength="120" placeholder="Ex.: Mercado, parques e museu" /></label>
		<label><span class="label">Quem vai</span><input type="text" bind:value={who} maxlength="300" placeholder="Ex.: Todos juntos" /></label>
	</div>
	<label><span class="label">Resumo / dica do dia</span><textarea bind:value={lead} maxlength="1000" rows="2"></textarea></label>
	<label class="check"><input type="checkbox" bind:checked={wedding} /> Dia do casamento</label>

	<h3>Paradas</h3>
	<ol class="stops">
		{#each stops as s, i (s.key)}
			<li class="card stop">
				<div class="top">
					<span class="n">{i + 1}</span>
					<div class="time">
						{#if s.clock}
							<input type="time" bind:value={s.time} aria-label="Horário da parada {i + 1}" />
						{:else}
							<input type="text" bind:value={s.time} maxlength="40" placeholder="Ex.: Ida e volta" aria-label="Quando (parada {i + 1})" />
						{/if}
						<button type="button" class="link" onclick={() => { s.clock = !s.clock; s.time = ''; }}>{s.clock ? 'texto' : 'hora'}</button>
					</div>
				</div>
				<select class="place" bind:value={s.placeId} onchange={() => placeChanged(s)} aria-label="Lugar da parada {i + 1}">
					<option value="">Sem lugar (só texto)</option>
					{#each grouped as [c, list]}
						<optgroup label={CATEGORY[c].plural}>
							{#each list as p (p.id)}<option value={p.id}>{p.name}</option>{/each}
						</optgroup>
					{/each}
					<option value="__new">＋ Cadastrar lugar novo…</option>
				</select>
				{#if !s.placeId}
					<input class="lbl" type="text" bind:value={s.label} maxlength="120" placeholder="O que é? (ex.: Salão do casamento)" aria-label="Nome da parada {i + 1}" />
				{/if}
				<label class="inline">
					<span>Como chegar</span>
					<select bind:value={s.transport}>
						{#each Object.entries(TRANSPORT) as [k, t]}<option value={k}>{t.label}</option>{/each}
					</select>
				</label>
				<textarea class="note" bind:value={s.note} maxlength="1000" rows="2" placeholder="Dicas, o que fazer lá…" aria-label="Observação da parada {i + 1}"></textarea>
				<div class="order">
					<button type="button" onclick={() => move(i, -1)} disabled={i === 0} aria-label="Subir parada {i + 1}">↑ Subir</button>
					<button type="button" onclick={() => move(i, 1)} disabled={i === stops.length - 1} aria-label="Descer parada {i + 1}">↓ Descer</button>
					<button type="button" onclick={() => removeStop(i)} aria-label="Remover parada {i + 1}" class="del">✕ Remover</button>
				</div>
			</li>
		{/each}
	</ol>
	<button type="button" class="btn secondary block" onclick={add}><Icon name="pin" size={18} /> Adicionar parada</button>
	<p class="small muted">Use horários (ex.: 9:35) para o app avisar 30 min antes. A rota no mapa segue a ordem das paradas.</p>

	{#if error}<p class="error small" role="alert">{error}</p>{/if}
	<div class="actions">
		{#if d0}<button type="button" class="btn small danger" onclick={removeDay} disabled={busy}>Apagar dia</button>{/if}
		<span class="grow"></span>
		<button type="button" class="btn secondary" onclick={onclose}>Cancelar</button>
		<button class="btn sun" disabled={busy}>{busy ? 'Salvando…' : 'Salvar dia'}</button>
	</div>
</form>

{#if creatingFor !== null}
	<PlaceEditor
		place={null}
		onclose={() => (creatingFor = null)}
		onsaved={onplaceschanged}
		oncreated={(id) => {
			const s = stops.find((x) => x.key === creatingFor);
			if (s) s.placeId = id;
		}}
	/>
{/if}

<style>
	.day-editor { display: grid; grid-template-columns: minmax(0, 1fr); gap: 12px; }
	.day-editor :global(select), .day-editor :global(input) { min-width: 0; max-width: 100%; }
	.head-fields { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; }
	.label { display: block; font-weight: 800; font-size: 0.9rem; margin-bottom: 6px; }
	.check { display: flex; align-items: center; gap: 8px; font-weight: 700; }
	.check input { width: 22px; height: 22px; }
	h3 { margin: 8px 0 0; }
	.stops { list-style: none; padding: 0; margin: 0; display: grid; gap: 12px; container-type: inline-size; }
	.stop { display: grid; grid-template-columns: minmax(0, 1fr); gap: 8px; padding: 12px; }
	.top { display: flex; align-items: center; gap: 8px; }
	.n { flex: none; display: grid; place-items: center; width: 30px; height: 30px; border-radius: 50%; background: var(--sun); color: #4a3410; font: 700 0.9rem var(--font-display); }
	.time { flex: 1; min-width: 0; display: flex; align-items: center; gap: 6px; }
	.time input { padding: 8px 12px; flex: 1; }
	.order { display: flex; gap: 6px; justify-content: flex-end; flex-wrap: wrap; }
	.order button { min-height: 36px; padding: 0 10px; font-weight: 800; font-size: 0.82rem; border-radius: 10px; border: 2px solid var(--line); background: var(--surface-2); color: var(--ink); cursor: pointer; }
	.order button:disabled { opacity: 0.35; }
	.order .del { color: var(--coral); }
	.inline { display: flex; align-items: center; gap: 10px; font-weight: 700; font-size: 0.9rem; }
	.inline span { flex: none; }
	.inline select { flex: 1; }
	.link { background: none; border: 0; color: var(--sea); font-weight: 800; cursor: pointer; padding: 4px; font-size: 0.8rem; }
	.actions { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
	.grow { flex: 1; }
	p { margin: 0; }
	/* wide (computers): time, place and transport side by side */
	@container (min-width: 620px) {
		.stop {
			grid-template-columns: 200px minmax(0, 1fr) 190px; align-items: center; column-gap: 10px;
			grid-template-areas: 'top place how' '. lbl lbl' 'note note note' 'order order order';
		}
		.top { grid-area: top; }
		.place { grid-area: place; }
		.lbl { grid-area: lbl; }
		.inline { grid-area: how; }
		.inline span { display: none; }
		.note { grid-area: note; }
		.order { grid-area: order; }
	}
</style>
