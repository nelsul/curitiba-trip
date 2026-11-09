<script lang="ts">
	import { onMount } from 'svelte';
	import Icon from './Icon.svelte';
	import { FRAME_SIZE, FRAME_STYLES, drawFrame, loadImage, type FrameFormat, type FrameStyle } from '$lib/frames';

	/** Builds one image with the chosen photos in a frame and shares it (Instagram, WhatsApp…) or downloads it. */
	let { ids, onclose }: { ids: string[]; onclose: () => void } = $props();

	let dialog: HTMLDialogElement;
	let canvas = $state<HTMLCanvasElement>();
	let style = $state<FrameStyle>('polaroid');
	let format = $state<FrameFormat>('post');
	let photos = $state<HTMLImageElement[]>([]);
	let error = $state('');
	let busy = $state(false);
	const canShare = typeof navigator !== 'undefined' && 'canShare' in navigator;

	onMount(() => {
		dialog.showModal();
		// same-origin copies, so the canvas can be exported
		Promise.all([document.fonts.load('600 76px Fredoka'), document.fonts.load('800 34px Nunito')]).catch(() => {});
		Promise.all(ids.map((id) => loadImage(`/api/media/${id}/file`)))
			.then((p) => (photos = p))
			.catch((e) => (error = (e as Error).message));
	});

	$effect(() => {
		if (canvas && photos.length) drawFrame(canvas, photos, style, format);
	});

	const blob = () => new Promise<Blob>((ok, fail) => canvas!.toBlob((b) => (b ? ok(b) : fail(new Error('Não foi possível gerar a imagem.'))), 'image/jpeg', 0.92));

	async function share() {
		busy = true;
		error = '';
		try {
			const file = new File([await blob()], 'curitiba.jpg', { type: 'image/jpeg' });
			if (canShare && navigator.canShare({ files: [file] })) await navigator.share({ files: [file] });
			else download(file);
		} catch (e) {
			if ((e as Error).name !== 'AbortError') error = (e as Error).message;
		} finally {
			busy = false;
		}
	}

	async function save() {
		try {
			download(await blob());
		} catch (e) {
			error = (e as Error).message;
		}
	}
	function download(b: Blob) {
		const a = document.createElement('a');
		a.href = URL.createObjectURL(b);
		a.download = 'curitiba.jpg';
		a.click();
		setTimeout(() => URL.revokeObjectURL(a.href), 2000);
	}
</script>

<dialog bind:this={dialog} class="maker" onclose={onclose} aria-labelledby="frame-title">
	<header>
		<h2 id="frame-title">Moldura</h2>
		<button class="x" onclick={() => dialog.close()} aria-label="Fechar"><Icon name="close" size={20} /></button>
	</header>
	<div class="preview" style:aspect-ratio="{FRAME_SIZE[format].w}/{FRAME_SIZE[format].h}"
		style:width="min(100%, calc((100dvh - 350px) * {FRAME_SIZE[format].w / FRAME_SIZE[format].h}))">
		{#if photos.length}<canvas bind:this={canvas} aria-label="Prévia da imagem com {ids.length} {ids.length === 1 ? 'foto' : 'fotos'}"></canvas>
		{:else if !error}<p class="muted">Preparando as fotos…</p>{/if}
	</div>
	<div class="chips" role="radiogroup" aria-label="Estilo">
		{#each Object.entries(FRAME_STYLES) as [k, s] (k)}
			<button class="chip" role="radio" aria-checked={style === k} onclick={() => (style = k as FrameStyle)}>
				<i style:background={s.bg} style:border-color={s.title}></i>{s.label}
			</button>
		{/each}
	</div>
	<div class="chips" role="radiogroup" aria-label="Formato">
		{#each Object.entries(FRAME_SIZE) as [k, f] (k)}
			<button class="chip" role="radio" aria-checked={format === k} onclick={() => (format = k as FrameFormat)}>{f.label}</button>
		{/each}
	</div>
	{#if error}<p class="error small" role="alert">{error}</p>{/if}
	<footer>
		<button class="btn secondary" onclick={save} disabled={!photos.length}><Icon name="download" size={18} /> Baixar</button>
		<button class="btn sun" onclick={share} disabled={!photos.length || busy}><Icon name="share" size={18} /> Compartilhar</button>
	</footer>
	<p class="small muted hint">No celular, “Compartilhar” abre o Instagram, o WhatsApp e os outros apps.</p>
</dialog>

<style>
	.maker { width: min(520px, 100vw); max-width: 100vw; max-height: 100dvh; margin: auto; padding: 0 16px 16px; border: 2.5px solid var(--line); border-radius: var(--radius); background: var(--bg); color: var(--ink); }
	.maker::backdrop { background: rgb(10 15 30 / 0.7); }
	.maker[open] { display: grid; gap: 12px; animation: pop-in 0.3s var(--bounce); }
	header { display: flex; align-items: center; justify-content: space-between; padding-top: 12px; }
	header h2 { margin: 0; }
	.x { width: 44px; height: 44px; border: 0; border-radius: 50%; background: var(--surface); color: var(--ink); display: grid; place-items: center; cursor: pointer; }
	.preview { margin: 0 auto; display: grid; place-items: center; background: var(--surface); border-radius: 12px; overflow: hidden; }
	canvas { width: 100%; height: 100%; display: block; }
	.chips { display: flex; flex-wrap: wrap; gap: 6px; justify-content: center; }
	.chip { gap: 6px; }
	.chip i { width: 14px; height: 14px; border-radius: 4px; border: 2px solid; display: inline-block; }
	.chip[aria-checked='true'] { background: var(--sea); border-color: var(--sea); color: var(--on-sea); }
	footer { display: flex; gap: 8px; justify-content: center; }
	.hint { margin: 0; text-align: center; }
	@media (max-width: 600px) { .maker { width: 100vw; height: 100dvh; border-radius: 0; border: 0; } }
</style>
