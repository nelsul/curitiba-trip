<script lang="ts">
	import { onMount } from 'svelte';
	import Icon from '$lib/components/Icon.svelte';
	import LocationPicker from '$lib/components/LocationPicker.svelte';
	import { CATEGORY, type PlaceCategory, type PlacePhoto, type RoteiroPlace } from '$lib/itinerary';
	import { api, uploadPlacePhoto } from '$lib/roteiro-client';

	let {
		place,
		onclose,
		onsaved,
		oncreated
	}: {
		/** null = new place */
		place: RoteiroPlace | null;
		onclose: () => void;
		/** after any change (save, photo, delete) so the page reloads its data */
		onsaved: () => void;
		/** a new place was created (the day editor puts it in the stop) */
		oncreated?: (id: string) => void;
	} = $props();

	// svelte-ignore state_referenced_locally
	const p = place;
	let name = $state(p?.name ?? '');
	let category = $state<PlaceCategory>(p?.category ?? 'comer');
	let lat = $state<number | null>(p?.lat ?? null);
	let lng = $state<number | null>(p?.lng ?? null);
	let address = $state(p?.address ?? '');
	let hours = $state(p?.hours ?? '');
	let price = $state(p?.price ?? '');
	let priceLevel = $state(p?.priceLevel == null ? '' : String(p.priceLevel));
	let description = $state(p?.description ?? '');
	let link = $state(p?.link ?? '');
	let photos = $state<PlacePhoto[]>(p?.photos ?? []);
	/** photos picked before a new place exists: sent right after it's created */
	let pending = $state<{ file: File; preview: string }[]>([]);
	let busy = $state(false);
	let uploading = $state(0);
	let error = $state('');
	let dialog: HTMLDialogElement;

	/** computers: map and photos on the left, the details on the right */
	let big = $state(false);
	onMount(() => {
		big = matchMedia('(min-width: 900px)').matches;
		dialog.showModal();
		return () => pending.forEach((x) => URL.revokeObjectURL(x.preview));
	});

	/** A place picked in the map search fills in the name and address when they're still empty. */
	function chosen(r: { name: string; detail: string }) {
		if (!name.trim()) name = r.name;
		if (!address.trim() && r.detail && r.detail !== 'Lugar da viagem') address = r.detail.replaceAll(' · ', ', ');
	}

	async function addFiles(e: Event) {
		const input = e.currentTarget as HTMLInputElement;
		const files = [...(input.files ?? [])];
		input.value = '';
		if (!p) {
			pending = [...pending, ...files.map((file) => ({ file, preview: URL.createObjectURL(file) }))];
			return;
		}
		await upload(p.id, files);
	}

	async function upload(id: string, files: File[]) {
		error = '';
		uploading += files.length;
		for (const f of files) {
			try {
				photos = [...photos, await uploadPlacePhoto(id, f)];
			} catch (err) {
				error = (err as Error).message;
			} finally {
				uploading--;
			}
		}
		onsaved();
	}

	async function removePhoto(ph: PlacePhoto) {
		if (!p || !confirm('Apagar esta foto?')) return;
		try {
			await api('DELETE', `/api/roteiro/places/${p.id}/photos/${ph.id}`);
			photos = photos.filter((x) => x.id !== ph.id);
			onsaved();
		} catch (err) {
			error = (err as Error).message;
		}
	}

	async function save(e: SubmitEvent) {
		e.preventDefault();
		error = '';
		if (lat == null || lng == null) {
			error = 'Marque o lugar no mapa (busque pelo nome ou toque no mapa).';
			return;
		}
		busy = true;
		const body = { name, category, lat, lng, address, hours, price, priceLevel: priceLevel === '' ? null : Number(priceLevel), description, link };
		try {
			if (p) await api('PATCH', `/api/roteiro/places/${p.id}`, body);
			else {
				const { id } = await api<{ id: string }>('POST', '/api/roteiro/places', body);
				oncreated?.(id);
				if (pending.length) await upload(id, pending.map((x) => x.file));
			}
			onsaved();
			if (!error) close();
		} catch (err) {
			error = (err as Error).message;
		} finally {
			busy = false;
		}
	}

	async function remove() {
		if (!p || !confirm(`Apagar "${p.name}" para todo mundo? Se estiver no roteiro, a parada fica só com o nome.`)) return;
		busy = true;
		try {
			await api('DELETE', `/api/roteiro/places/${p.id}`);
			onsaved();
			close();
		} catch (err) {
			error = (err as Error).message;
		} finally {
			busy = false;
		}
	}

	function close() {
		dialog.close();
	}
</script>

<dialog bind:this={dialog} class="editor" onclose={onclose} aria-labelledby="place-editor-title">
	<form onsubmit={save}>
		<header>
			<h2 id="place-editor-title">{p ? 'Editar lugar' : 'Novo lugar'}</h2>
			<button type="button" class="x" onclick={close} aria-label="Fechar">✕</button>
		</header>

		<fieldset class="cats">
			<legend class="sr-only">Tipo</legend>
			{#each Object.entries(CATEGORY) as [k, c]}
				<label class="chip" style:--c={c.color} class:on={category === k}>
					<input type="radio" name="category" value={k} bind:group={category} class="sr-only" />{c.label}
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
			<input type="text" bind:value={name} required maxlength="120" placeholder="Ex.: Bar do Alemão" />
		</label>
		<label>
			<span class="label">Endereço</span>
			<input type="text" bind:value={address} maxlength="200" placeholder="Rua, bairro" />
		</label>
		<label>
			<span class="label">Horário de funcionamento</span>
			<input type="text" bind:value={hours} maxlength="300" placeholder="Ex.: ter–sáb 11h–23h; fecha seg" />
		</label>
		<div class="row2">
			<label>
				<span class="label">Faixa de preço</span>
				<select bind:value={priceLevel}>
					<option value="">Não sei</option>
					<option value="0">Grátis</option>
					<option value="1">$ (barato)</option>
					<option value="2">$$</option>
					<option value="3">$$$</option>
					<option value="4">$$$$ (caro)</option>
				</select>
			</label>
			<label>
				<span class="label">Preço</span>
				<input type="text" bind:value={price} maxlength="120" placeholder="R$ 60–90 por pessoa" />
			</label>
		</div>
		<label>
			<span class="label">Sobre</span>
			<textarea bind:value={description} maxlength="2000" rows="3" placeholder="O que pedir, dicas, reservas…"></textarea>
		</label>
		<label>
			<span class="label">Site ou Instagram</span>
			<input type="url" bind:value={link} maxlength="500" placeholder="https://" inputmode="url" />
		</label>
		</div>

		<section class="pics">
			<span class="label">Fotos</span>
			<div class="thumbs">
				{#each photos as ph (ph.id)}
					<div class="thumb">
						<img src={ph.url} alt="" />
						<button type="button" onclick={() => removePhoto(ph)} aria-label="Apagar foto">✕</button>
					</div>
				{/each}
				{#each pending as ph (ph.preview)}
					<div class="thumb"><img src={ph.preview} alt="" /></div>
				{/each}
				{#each { length: uploading } as _}<div class="thumb loading" aria-label="Enviando foto"></div>{/each}
				<label class="thumb add">
					<Icon name="camera" size={24} /><span>Adicionar</span>
					<input type="file" accept="image/*" multiple onchange={addFiles} class="sr-only" />
				</label>
			</div>
		</section>

		{#if error}<p class="error small err" role="alert">{error}</p>{/if}

		<footer>
			{#if p}<button type="button" class="btn small danger" onclick={remove} disabled={busy}>Apagar</button>{/if}
			<span class="grow"></span>
			<button type="button" class="btn secondary" onclick={close}>Cancelar</button>
			<button class="btn sun" disabled={busy || uploading > 0}>{busy ? 'Salvando…' : 'Salvar'}</button>
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
	.cats { border: 0; padding: 0; margin: 0; display: flex; gap: 8px; flex-wrap: wrap; }
	.cats .chip.on { background: var(--c); border-color: var(--c); color: #fff; }
	.fields { display: grid; grid-template-columns: minmax(0, 1fr); gap: 14px; align-content: start; }
	.row2 { display: grid; grid-template-columns: 1fr 1.4fr; gap: 10px; }
	.thumbs { display: grid; grid-template-columns: repeat(auto-fill, minmax(88px, 1fr)); gap: 8px; }
	.thumb { position: relative; aspect-ratio: 1; border-radius: 12px; overflow: hidden; background: var(--surface-2); border: 2px solid var(--line); }
	.thumb img { width: 100%; height: 100%; object-fit: cover; }
	.thumb button { position: absolute; top: 4px; right: 4px; width: 30px; height: 30px; border-radius: 50%; border: 0; background: rgb(0 0 0 / 0.6); color: #fff; cursor: pointer; }
	.thumb.add { display: grid; place-content: center; justify-items: center; gap: 2px; color: var(--muted); font-weight: 800; font-size: 0.8rem; cursor: pointer; border-style: dashed; }
	.thumb.loading { background: linear-gradient(90deg, var(--surface-2), var(--surface), var(--surface-2)); background-size: 200% 100%; animation: shimmer 1s linear infinite; }
	@keyframes shimmer { to { background-position: -200% 0; } }
	footer { position: sticky; bottom: 0; display: flex; gap: 8px; align-items: center; padding: 10px 0 0; background: var(--bg); }
	.grow { flex: 1; }
	@media (min-width: 900px) {
		.editor { width: min(1000px, calc(100vw - 48px)); }
		form {
			grid-template-columns: minmax(0, 1.1fr) minmax(0, 1fr); column-gap: 24px;
			grid-template-areas: 'head head' 'cats fields' 'where fields' 'pics fields' 'err err' 'foot foot';
		}
		header { grid-area: head; }
		.cats { grid-area: cats; }
		.where { grid-area: where; }
		.fields { grid-area: fields; }
		.pics { grid-area: pics; }
		.err { grid-area: err; }
		footer { grid-area: foot; }
		.fields textarea { min-height: 140px; }
	}
	@media (max-width: 600px) {
		.editor { width: 100vw; height: 100dvh; border-radius: 0; border: 0; }
		.row2 { grid-template-columns: 1fr; }
	}
</style>
