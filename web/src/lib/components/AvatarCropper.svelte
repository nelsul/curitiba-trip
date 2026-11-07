<script lang="ts">
	import { onDestroy } from 'svelte';
	import Icon from './Icon.svelte';

	/** Lets the user frame a photo inside a circle (drag to move, pinch / wheel / slider to zoom). */
	let {
		file,
		oncancel,
		ondone
	}: { file: File; oncancel: () => void; ondone: (blob: Blob) => void } = $props();

	const STAGE = 280; // px, the square stage; the circle fills it
	const OUT = 512; // exported square size

	let dialog: HTMLDialogElement;
	let img = $state<HTMLImageElement | null>(null);
	let error = $state('');
	let saving = $state(false);
	let nw = $state(0);
	let nh = $state(0);
	let minScale = $state(1);
	let scale = $state(1); // displayed px per natural px
	let x = $state(0); // image top-left inside the stage
	let y = $state(0);

	// The cropper is created fresh for each picked file, so reading `file` once is intended.
	// svelte-ignore state_referenced_locally
	const url = URL.createObjectURL(file);
	onDestroy(() => URL.revokeObjectURL(url));

	$effect(() => {
		dialog?.showModal();
	});

	(async () => {
		const el = new Image();
		el.src = url;
		try {
			await el.decode();
		} catch {
			error = 'Não foi possível abrir essa imagem. Tente outra (JPG ou PNG).';
			return;
		}
		nw = el.naturalWidth;
		nh = el.naturalHeight;
		minScale = STAGE / Math.min(nw, nh);
		scale = minScale;
		x = (STAGE - nw * scale) / 2;
		y = (STAGE - nh * scale) / 2;
		img = el;
	})();

	/** Keep the circle fully covered by the image. */
	function clamp(nx: number, ny: number, s: number) {
		const w = nw * s, h = nh * s;
		return { x: Math.min(0, Math.max(STAGE - w, nx)), y: Math.min(0, Math.max(STAGE - h, ny)) };
	}

	function zoomTo(next: number, cx = STAGE / 2, cy = STAGE / 2) {
		const s = Math.max(minScale, Math.min(minScale * 6, next));
		// keep the point under (cx, cy) fixed while zooming
		const ix = (cx - x) / scale, iy = (cy - y) / scale;
		const c = clamp(cx - ix * s, cy - iy * s, s);
		scale = s;
		x = c.x;
		y = c.y;
	}

	const pointers = new Map<number, { x: number; y: number }>();
	let pinchStart: { dist: number; scale: number; cx: number; cy: number } | null = null;

	function local(e: PointerEvent) {
		const r = (e.currentTarget as HTMLElement).getBoundingClientRect();
		return { x: e.clientX - r.left, y: e.clientY - r.top };
	}

	function down(e: PointerEvent) {
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		pointers.set(e.pointerId, local(e));
		if (pointers.size === 2) {
			const [a, b] = [...pointers.values()];
			pinchStart = { dist: Math.hypot(a.x - b.x, a.y - b.y), scale, cx: (a.x + b.x) / 2, cy: (a.y + b.y) / 2 };
		}
	}

	function move(e: PointerEvent) {
		const prev = pointers.get(e.pointerId);
		if (!prev) return;
		const p = local(e);
		pointers.set(e.pointerId, p);
		if (pointers.size === 2 && pinchStart) {
			const [a, b] = [...pointers.values()];
			zoomTo(pinchStart.scale * (Math.hypot(a.x - b.x, a.y - b.y) / pinchStart.dist), pinchStart.cx, pinchStart.cy);
		} else if (pointers.size === 1) {
			const c = clamp(x + p.x - prev.x, y + p.y - prev.y, scale);
			x = c.x;
			y = c.y;
		}
	}

	function up(e: PointerEvent) {
		pointers.delete(e.pointerId);
		if (pointers.size < 2) pinchStart = null;
	}

	function wheel(e: WheelEvent) {
		e.preventDefault();
		const r = (e.currentTarget as HTMLElement).getBoundingClientRect();
		zoomTo(scale * Math.exp(-e.deltaY * 0.0015), e.clientX - r.left, e.clientY - r.top);
	}

	function keys(e: KeyboardEvent) {
		const step = 12;
		const moves: Record<string, [number, number]> = { ArrowLeft: [step, 0], ArrowRight: [-step, 0], ArrowUp: [0, step], ArrowDown: [0, -step] };
		if (moves[e.key]) {
			e.preventDefault();
			const c = clamp(x + moves[e.key][0], y + moves[e.key][1], scale);
			x = c.x;
			y = c.y;
		} else if (e.key === '+' || e.key === '=') zoomTo(scale * 1.1);
		else if (e.key === '-') zoomTo(scale / 1.1);
	}

	async function save() {
		if (!img) return;
		saving = true;
		const side = STAGE / scale; // natural px under the circle
		const out = Math.min(OUT, Math.round(side));
		const canvas = document.createElement('canvas');
		canvas.width = canvas.height = out;
		const ctx = canvas.getContext('2d')!;
		ctx.imageSmoothingQuality = 'high';
		ctx.drawImage(img, -x / scale, -y / scale, side, side, 0, 0, out, out);
		let blob = await new Promise<Blob | null>((r) => canvas.toBlob(r, 'image/webp', 0.86));
		if (!blob || blob.type !== 'image/webp') blob = await new Promise<Blob | null>((r) => canvas.toBlob(r, 'image/jpeg', 0.88));
		ondone(blob!);
	}

	const zoomPct = $derived(minScale ? Math.round((scale / minScale) * 100) : 100);
</script>

<dialog bind:this={dialog} class="card cropper" oncancel={(e) => { e.preventDefault(); oncancel(); }}>
	<h2>Ajustar foto</h2>
	<p class="muted small">Arraste para mover e use o controle (ou dois dedos) para aproximar.</p>

	{#if error}
		<p class="error">{error}</p>
	{:else}
		<!-- Drag/pinch/keyboard framing surface. -->
		<!-- svelte-ignore a11y_no_noninteractive_tabindex, a11y_no_noninteractive_element_interactions -->
		<div
			class="stage"
			style:width="{STAGE}px"
			style:height="{STAGE}px"
			onpointerdown={down}
			onpointermove={move}
			onpointerup={up}
			onpointercancel={up}
			onwheel={wheel}
			onkeydown={keys}
			tabindex="0"
			role="application"
			aria-label="Área de enquadramento. Use as setas para mover e + ou - para aproximar."
		>
			{#if img}
				<img src={url} alt="" draggable="false" style:width="{nw * scale}px" style:height="{nh * scale}px" style:transform="translate({x}px, {y}px)" />
			{:else}
				<p class="loading">Abrindo…</p>
			{/if}
			<span class="ring" aria-hidden="true"></span>
		</div>

		<label class="zoom">
			<Icon name="camera" size={16} />
			<input type="range" min="100" max="600" step="1" value={zoomPct} oninput={(e) => zoomTo(minScale * (Number(e.currentTarget.value) / 100))} aria-label="Zoom" />
			<span class="small">{zoomPct}%</span>
		</label>
	{/if}

	<div class="row">
		<button type="button" class="btn secondary" onclick={oncancel} disabled={saving}>Cancelar</button>
		<button type="button" class="btn sun" onclick={save} disabled={!img || saving}>{saving ? 'Salvando…' : 'Usar foto'}</button>
	</div>
</dialog>

<style>
	.cropper { border: 2.5px solid var(--line); width: min(360px, calc(100vw - 24px)); color: var(--ink); display: grid; gap: 12px; justify-items: center; }
	.cropper[open] { animation: pop-in 0.35s var(--bounce); }
	.cropper::backdrop { background: rgb(40 30 20 / 0.55); }
	h2, p { margin: 0; text-align: center; }
	.stage {
		position: relative; overflow: hidden; border-radius: 18px; background: #222; touch-action: none; cursor: grab;
		user-select: none; -webkit-user-select: none;
	}
	.stage:active { cursor: grabbing; }
	.stage img { position: absolute; left: 0; top: 0; max-width: none; transform-origin: 0 0; pointer-events: none; }
	/* the circle: everything outside it is dimmed */
	.ring { position: absolute; inset: 0; border-radius: 50%; box-shadow: 0 0 0 200px rgb(20 15 10 / 0.6); border: 3px dashed rgb(255 255 255 / 0.85); pointer-events: none; }
	.loading { position: absolute; inset: 0; display: grid; place-items: center; color: #fff; }
	.zoom { display: flex; align-items: center; gap: 10px; width: 100%; color: var(--muted); }
	.zoom input { flex: 1; accent-color: var(--sea); }
	.row { display: flex; gap: 8px; justify-content: flex-end; width: 100%; }
</style>
