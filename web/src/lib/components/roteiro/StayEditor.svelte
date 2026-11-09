<script lang="ts">
	import { onMount } from 'svelte';
	import LocationPicker from '$lib/components/LocationPicker.svelte';
	import { STAY_KIND, type RoteiroStay, type StayKind } from '$lib/itinerary';
	import { api } from '$lib/roteiro-client';

	type Person = { id: string; name: string; color: string; photo: string | null };
	let {
		stay,
		persons,
		firstDay,
		lastDay,
		onclose,
		onsaved
	}: {
		/** null = new stay */
		stay: RoteiroStay | null;
		persons: Person[];
		/** the trip's first and last day: suggested check-in and check-out for a new stay */
		firstDay: string;
		lastDay: string;
		onclose: () => void;
		onsaved: () => void;
	} = $props();

	// svelte-ignore state_referenced_locally
	const s = stay;
	let name = $state(s?.name ?? '');
	let kind = $state<StayKind>(s?.kind ?? 'airbnb');
	let lat = $state<number | null>(s?.lat ?? null);
	let lng = $state<number | null>(s?.lng ?? null);
	let address = $state(s?.address ?? '');
	let link = $state(s?.link ?? '');
	// svelte-ignore state_referenced_locally
	let checkIn = $state(s ? (s.checkIn ?? '') : firstDay);
	// svelte-ignore state_referenced_locally
	let checkOut = $state(s ? (s.checkOut ?? '') : lastDay);
	let note = $state(s?.note ?? '');
	let guests = $state<string[]>(s?.guests ?? []);
	let busy = $state(false);
	let error = $state('');
	let dialog: HTMLDialogElement;

	let big = $state(false);
	onMount(() => {
		big = matchMedia('(min-width: 900px)').matches;
		dialog.showModal();
	});

	function chosen(r: { name: string; detail: string }) {
		if (!name.trim()) name = r.name;
		if (!address.trim() && r.detail && r.detail !== 'Lugar da viagem') address = r.detail.replaceAll(' · ', ', ');
	}

	const toggle = (id: string) => (guests = guests.includes(id) ? guests.filter((g) => g !== id) : [...guests, id]);

	async function save(e: SubmitEvent) {
		e.preventDefault();
		error = '';
		if (lat == null || lng == null) {
			error = 'Marque a hospedagem no mapa (busque pelo endereço ou toque no mapa).';
			return;
		}
		busy = true;
		const body = { name, kind, lat, lng, address, link, checkIn: checkIn || null, checkOut: checkOut || null, note, guests };
		try {
			if (s) await api('PUT', `/api/admin/stays/${s.id}`, body);
			else await api('POST', '/api/admin/stays', body);
			onsaved();
			dialog.close();
		} catch (err) {
			error = (err as Error).message;
		} finally {
			busy = false;
		}
	}

	async function remove() {
		if (!s || !confirm(`Apagar "${s.name}"? Quem estava lá fica sem hospedagem no roteiro.`)) return;
		busy = true;
		try {
			await api('DELETE', `/api/admin/stays/${s.id}`);
			onsaved();
			dialog.close();
		} catch (err) {
			error = (err as Error).message;
		} finally {
			busy = false;
		}
	}
</script>

<dialog bind:this={dialog} class="editor" onclose={onclose} aria-labelledby="stay-editor-title">
	<form onsubmit={save}>
		<header>
			<h2 id="stay-editor-title">{s ? 'Editar hospedagem' : 'Nova hospedagem'}</h2>
			<button type="button" class="x" onclick={() => dialog.close()} aria-label="Fechar">✕</button>
		</header>

		<fieldset class="kinds">
			<legend class="sr-only">Tipo</legend>
			{#each Object.entries(STAY_KIND) as [k, t]}
				<label class="chip" class:on={kind === k}>
					<input type="radio" name="kind" value={k} bind:group={kind} class="sr-only" />{t.emoji} {t.label}
				</label>
			{/each}
		</fieldset>

		<section class="where">
			<span class="label">Onde fica</span>
			<LocationPicker bind:lat bind:lng editable onchoose={chosen} height={big ? 340 : 220} />
		</section>

		<div class="fields">
			<label>
				<span class="label">Nome</span>
				<input type="text" bind:value={name} required maxlength="120" placeholder="Ex.: Airbnb do Batel" />
			</label>
			<label>
				<span class="label">Endereço</span>
				<input type="text" bind:value={address} maxlength="200" placeholder="Rua, número, bairro" />
			</label>
			<div class="row2">
				<label>
					<span class="label">Chegada (1ª noite)</span>
					<input type="date" bind:value={checkIn} />
				</label>
				<label>
					<span class="label">Saída</span>
					<input type="date" bind:value={checkOut} min={checkIn || undefined} />
				</label>
			</div>
			<p class="small muted hint">Do dia da chegada ao dia da saída, o roteiro de quem fica aqui começa e termina aqui. Sem datas = a viagem toda.</p>

			<fieldset class="guests">
				<legend class="label">Quem fica aqui ({guests.length})</legend>
				<div class="people">
					{#each persons as p (p.id)}
						<label class="person" class:on={guests.includes(p.id)} style:--c={p.color}>
							<input type="checkbox" checked={guests.includes(p.id)} onchange={() => toggle(p.id)} class="sr-only" />
							{#if p.photo}<img src={p.photo} alt="" />{:else}<span class="ini" aria-hidden="true">{p.name.slice(0, 1)}</span>{/if}
							<span>{p.name}</span>
							{#if guests.includes(p.id)}<b aria-hidden="true">✓</b>{/if}
						</label>
					{/each}
				</div>
			</fieldset>

			<label>
				<span class="label">Site / link da reserva</span>
				<input type="url" bind:value={link} maxlength="500" placeholder="https://" inputmode="url" />
			</label>
			<label>
				<span class="label">Observações</span>
				<textarea bind:value={note} maxlength="1000" rows="2" placeholder="Check-in às 15h, código da porta com o Nelson…"></textarea>
			</label>
		</div>

		{#if error}<p class="error small err" role="alert">{error}</p>{/if}

		<footer>
			{#if s}<button type="button" class="btn small danger" onclick={remove} disabled={busy}>Apagar</button>{/if}
			<span class="grow"></span>
			<button type="button" class="btn secondary" onclick={() => dialog.close()}>Cancelar</button>
			<button class="btn sun" disabled={busy}>{busy ? 'Salvando…' : 'Salvar'}</button>
		</footer>
	</form>
</dialog>

<style>
	.editor {
		width: min(560px, 100vw); max-width: 100vw; max-height: 100dvh; margin: auto; padding: 0;
		border: 2.5px solid var(--line); border-radius: var(--radius); background: var(--bg); color: var(--ink);
	}
	.editor[open] { animation: pop-in 0.3s var(--bounce); }
	.editor::backdrop { background: rgb(10 15 30 / 0.6); }
	form { display: grid; grid-template-columns: minmax(0, 1fr); gap: 14px; padding: 0 16px 16px; }
	header { position: sticky; top: 0; z-index: 3; display: flex; align-items: center; justify-content: space-between; padding: 14px 0 10px; background: var(--bg); }
	header h2 { margin: 0; }
	.x { width: 44px; height: 44px; border: 0; border-radius: 50%; background: var(--surface); color: var(--ink); font-size: 1.1rem; cursor: pointer; }
	.label { display: block; font-weight: 800; font-size: 0.9rem; margin-bottom: 6px; }
	label { display: block; }
	fieldset { border: 0; padding: 0; margin: 0; min-width: 0; }
	.kinds { display: flex; gap: 8px; flex-wrap: wrap; }
	.kinds .chip.on { background: var(--sea); border-color: var(--sea); color: #fff; }
	.fields { display: grid; grid-template-columns: minmax(0, 1fr); gap: 14px; align-content: start; }
	.row2 { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
	.hint { margin: -8px 0 0; }
	.people { display: flex; flex-wrap: wrap; gap: 8px; }
	.person {
		position: relative; display: inline-flex; align-items: center; gap: 8px; padding: 4px 12px 4px 4px; min-height: 44px; cursor: pointer;
		border: 2.5px dashed var(--line); border-radius: 999px; background: var(--surface); font-weight: 800;
	}
	.person img, .person .ini { width: 32px; height: 32px; border-radius: 50%; object-fit: cover; }
	.person .ini { display: grid; place-items: center; background: var(--c); color: #fff; }
	.person.on { border-style: solid; border-color: var(--leaf); background: color-mix(in srgb, var(--leaf) 18%, var(--surface)); }
	.person b { color: var(--leaf); }
	.person:focus-within { outline: 3px solid var(--sea); outline-offset: 2px; }
	footer { position: sticky; bottom: 0; display: flex; gap: 8px; align-items: center; padding: 10px 0 0; background: var(--bg); }
	.grow { flex: 1; }
	@media (min-width: 900px) {
		.editor { width: min(1000px, calc(100vw - 48px)); }
		form {
			grid-template-columns: minmax(0, 1.1fr) minmax(0, 1fr); column-gap: 24px;
			grid-template-areas: 'head head' 'kinds fields' 'where fields' 'err err' 'foot foot';
			grid-template-rows: auto auto 1fr auto auto;
		}
		header { grid-area: head; }
		.kinds { grid-area: kinds; }
		.where { grid-area: where; }
		.fields { grid-area: fields; }
		.err { grid-area: err; }
		footer { grid-area: foot; }
	}
	@media (max-width: 600px) {
		.editor { width: 100vw; height: 100dvh; border-radius: 0; border: 0; }
	}
</style>
