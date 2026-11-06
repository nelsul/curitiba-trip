<script lang="ts">
	import { onDestroy } from 'svelte';
	import { invalidateAll } from '$app/navigation';
	import { readMeta, uploadFile, type FileMeta } from '$lib/uploader';
	import { currentPosition } from '$lib/location.svelte';
	import { fmtBytes, fmtDateTime } from '$lib/format';
	import UploadFlight from '$lib/components/UploadFlight.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import { fly } from 'svelte/transition';
	import { backOut } from 'svelte/easing';

	type Item = {
		key: number;
		file: File;
		meta: FileMeta | null;
		preview: string | null;
		caption: string;
		useDevice: boolean;
		state: 'ready' | 'uploading' | 'done' | 'error';
		sent: number;
		status: string;
		error: string;
		mediaId?: string;
	};

	let items = $state<Item[]>([]);
	let running = $state(false);
	let device = $state<{ lat: number; lng: number } | null>(null);
	let deviceError = $state('');
	let controller: AbortController | null = null;
	let wakeLock: WakeLockSentinel | null = null;
	let seq = 0;

	const previewable = (f: File) => /^image\/(jpeg|png|webp|gif|avif)$/.test(f.type) || /^video\/(mp4|webm|quicktime)$/.test(f.type);
	const FRESH_MS = 2 * 3600_000;

	async function pick(e: Event) {
		const input = e.currentTarget as HTMLInputElement;
		const files = [...(input.files ?? [])];
		input.value = '';
		const added = files.map((file) => ({
			key: ++seq,
			file,
			meta: null,
			preview: previewable(file) ? URL.createObjectURL(file) : null,
			caption: '',
			useDevice: false,
			state: 'ready' as const,
			sent: 0,
			status: '',
			error: ''
		}));
		items.push(...added);
		const needDevice: Item[] = [];
		for (const a of added) {
			const it = items.find((i) => i.key === a.key)!;
			it.meta = await readMeta(it.file);
			if (!it.meta.kind) it.error = 'Tipo de arquivo não suportado.';
			// Use the phone's current position only for things captured recently (or with unknown time).
			const fresh = it.meta.takenAtSource !== 'exif' || Date.now() - new Date(it.meta.takenAt!).getTime() < FRESH_MS;
			if (it.meta.locationSource !== 'exif' && fresh) needDevice.push(it);
		}
		if (needDevice.length) {
			try {
				const p = await currentPosition();
				device = { lat: p.lat, lng: p.lng };
				for (const it of needDevice) it.useDevice = true;
			} catch (err) {
				deviceError = (err as Error).message;
			}
		}
	}

	function remove(it: Item) {
		if (it.preview) URL.revokeObjectURL(it.preview);
		items = items.filter((i) => i !== it);
	}

	const pending = $derived(items.filter((i) => i.state !== 'done' && !(i.state === 'ready' && i.error) && i.meta?.kind));
	const total = $derived(items.reduce((a, i) => a + (i.meta?.kind ? i.file.size : 0), 0));
	const sentTotal = $derived(items.reduce((a, i) => a + (i.state === 'done' ? i.file.size : i.sent), 0));
	const allDone = $derived(items.length > 0 && items.every((i) => i.state === 'done' || !i.meta?.kind));

	function warnUnload(e: BeforeUnloadEvent) {
		if (running) e.preventDefault();
	}

	async function start() {
		running = true;
		controller = new AbortController();
		try { wakeLock = await navigator.wakeLock?.request('screen'); } catch {}
		for (const it of items) {
			if (it.state === 'done' || !it.meta?.kind || controller.signal.aborted) continue;
			it.state = 'uploading';
			it.error = '';
			it.sent = 0;
			const meta: FileMeta = { ...it.meta };
			if (meta.locationSource !== 'exif') {
				if (it.useDevice && device) Object.assign(meta, { lat: device.lat, lng: device.lng, locationSource: 'device' });
				else Object.assign(meta, { lat: null, lng: null, locationSource: null });
			}
			try {
				it.mediaId = await uploadFile({
					file: it.file,
					meta,
					caption: it.caption,
					signal: controller.signal,
					onProgress: (n) => (it.sent = n),
					onStatus: (s) => (it.status = s)
				});
				it.state = 'done';
				it.status = '';
			} catch (e) {
				it.state = 'error';
				it.status = '';
				it.error = (e as Error).name === 'AbortError' ? 'Cancelado.' : (e as Error).message;
			}
		}
		running = false;
		wakeLock?.release().catch(() => {});
		wakeLock = null;
		invalidateAll();
	}

	function cancel() {
		controller?.abort();
	}

	onDestroy(() => {
		controller?.abort();
		for (const i of items) if (i.preview) URL.revokeObjectURL(i.preview);
	});
</script>

<svelte:window onbeforeunload={warnUnload} />
<svelte:head><title>Enviar · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<div class="title-row"><span class="title-icon"><Icon name="upload" size={26} /></span><h1>Enviar</h1></div>
	<p class="muted">Fotos e vídeos vão no arquivo original, em qualidade total. O local e a hora vêm da própria foto quando ela tem essa informação.</p>

	<label class="picker" class:disabled={running}>
		<input type="file" accept="image/*,video/*,.heic,.heif,.mov" multiple onchange={pick} disabled={running} />
		<span class="picker-art" aria-hidden="true"><Icon name="camera" size={34} /></span>
		<strong>Escolher fotos e vídeos</strong>
		<span class="small muted">Pode escolher vários de uma vez</span>
	</label>

	<details class="tip small">
		<summary>Dica para iPhone</summary>
		<p>Na tela de escolher fotos, se aparecer o botão <strong>Opções</strong>, deixe o formato em <strong>Atual</strong> para enviar o arquivo original, sem conversão.</p>
		<p>Se o local da foto não vier junto, o app usa sua localização atual (para fotos recentes) ou você marca o lugar depois, no mapa.</p>
	</details>

	{#if deviceError}<p class="error small">{deviceError}</p>{/if}

	{#if items.length}
		<ul class="list">
			{#each items as it, i (it.key)}
				<li class="card item" class:done={it.state === 'done'} in:fly={{ y: 24, duration: 450, delay: Math.min(i, 6) * 70, easing: backOut }}>
					<div class="thumb">
						{#if it.preview && it.file.type.startsWith('image/')}
							<img src={it.preview} alt="" />
						{:else if it.preview}
							<video src={it.preview} muted playsinline preload="metadata"></video>
						{:else}
							<Icon name={it.meta?.kind === 'video' ? 'play' : 'camera'} size={30} />
						{/if}
					</div>
					<div class="info">
						<div class="row">
							<strong class="name">{it.file.name}</strong>
							{#if it.state === 'ready' && !running}
								<button class="x" onclick={() => remove(it)} aria-label="Remover {it.file.name}">×</button>
							{/if}
						</div>
						<p class="small muted">
							{fmtBytes(it.file.size)}
							{#if it.meta?.takenAtSource === 'exif'} · {fmtDateTime(it.meta.takenAt!)}{/if}
						</p>
						{#if it.meta}
							<p class="small">
								{#if it.meta.locationSource === 'exif'}
									<span class="loc ok"><Icon name="pin" size={15} /> Local da foto</span>
								{:else if device && it.state === 'ready' && !running}
									<label class="check"><input type="checkbox" bind:checked={it.useDevice} /> Usar minha localização atual</label>
								{:else if it.useDevice && device}
									<span class="loc ok"><Icon name="pin" size={15} /> Sua localização atual</span>
								{:else}
									<span class="muted">Sem local{it.meta.kind === 'video' ? ' (o vídeo pode ter; vamos verificar)' : ' — dá para marcar depois'}</span>
								{/if}
							</p>
						{/if}
						{#if it.state === 'ready' && it.meta?.kind}
							<textarea bind:value={it.caption} placeholder="Comentário (opcional)" rows="2" disabled={running}></textarea>
						{:else if it.caption}
							<p class="small">“{it.caption}”</p>
						{/if}
						{#if it.state === 'uploading' || it.state === 'done' || (it.state === 'error' && it.sent > 0)}
							<UploadFlight progress={it.sent / it.file.size} done={it.state === 'done'} failed={it.state === 'error'} label="Envio de {it.file.name}" />
							<p class="small muted">
								{#if it.state === 'done'}<a href="/m/{it.mediaId}">Ver no diário</a>
								{:else if it.state === 'uploading'}{it.status || `Voando… ${Math.floor((it.sent / it.file.size) * 100)}%`}{/if}
							</p>
						{/if}
						{#if it.error}<p class="error small">{it.error}</p>{/if}
					</div>
				</li>
			{/each}
		</ul>

		<div class="actions">
			{#if running}
				<p class="small">Enviando {fmtBytes(sentTotal)} de {fmtBytes(total)}. Mantenha esta tela aberta.</p>
				<button class="btn danger block" onclick={cancel}>Cancelar</button>
			{:else if allDone}
				<p>Tudo enviado! As fotos aparecem na linha do tempo em instantes; vídeos levam alguns minutos para ficarem prontos.</p>
				<a class="btn block" href="/">Ver linha do tempo</a>
			{:else}
				<button class="btn sun block" onclick={start} disabled={!pending.length}>
					Enviar {pending.length} {pending.length === 1 ? 'arquivo' : 'arquivos'} ({fmtBytes(pending.reduce((a, i) => a + i.file.size, 0))})
				</button>
			{/if}
		</div>
	{/if}
</main>

<style>
	.picker {
		display: grid; justify-items: center; gap: 6px; padding: 26px 16px; margin: 16px 0; border: 3px dashed var(--sea);
		border-radius: var(--radius); background: var(--surface); cursor: pointer; text-align: center; font-family: var(--font-display);
		font-size: 1.1rem; transition: transform 0.2s var(--bounce);
	}
	.picker:hover { transform: scale(1.01) rotate(-0.5deg); }
	.picker:active { transform: scale(0.98); }
	.picker-art { display: grid; place-items: center; width: 64px; height: 64px; border-radius: 22px; background: var(--sea); color: #fff; box-shadow: 0 4px 0 var(--sea-dark); transform: rotate(-6deg); animation: wiggle 3s ease-in-out infinite; }
	.picker.disabled { opacity: 0.5; cursor: default; }
	.picker input { position: absolute; opacity: 0; width: 1px; height: 1px; }
	.picker:focus-within { outline: 3px solid var(--pine); outline-offset: 2px; }
	.tip { margin-bottom: 16px; }
	.tip summary { cursor: pointer; color: var(--pine); font-weight: 600; min-height: 32px; }
	.tip p { margin: 6px 0; }
	.list { list-style: none; padding: 0; margin: 0; display: grid; gap: 12px; }
	.item { display: grid; grid-template-columns: 88px 1fr; gap: 12px; padding: 12px; }
	.item.done { opacity: 0.8; }
	.thumb { width: 88px; height: 88px; border-radius: 6px; border: 4px solid #fff; box-shadow: 0 3px 8px rgb(90 69 48 / 0.25); rotate: -2deg; color: var(--muted); overflow: hidden; background: var(--track); display: grid; place-items: center; font-size: 2rem; }
	.thumb img, .thumb video { width: 100%; height: 100%; object-fit: cover; }
	.info { min-width: 0; display: grid; gap: 4px; align-content: start; }
	.info p { margin: 0; }
	.row { display: flex; gap: 8px; align-items: start; }
	.name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1; }
	.x { border: 0; background: none; font-size: 1.5rem; line-height: 1; min-width: 36px; min-height: 36px; cursor: pointer; color: var(--muted); margin: -6px -6px 0 0; }
	.check { display: inline-flex; gap: 6px; align-items: center; min-height: 32px; }
	.check input { width: 18px; height: 18px; }
	textarea { min-height: 56px; margin-top: 4px; }
	.loc { display: inline-flex; align-items: center; gap: 4px; font-weight: 800; }
	.loc.ok { color: var(--leaf); }
	.actions { border: 2.5px solid var(--line); box-shadow: 0 4px 0 var(--shadow);
		margin-top: 16px; padding: 12px; background: var(--surface); border-radius: var(--radius); display: grid; gap: 8px; }
	.actions p { margin: 0; }
</style>
