<script lang="ts">
	import { invalidateAll } from '$app/navigation';
	import Avatar from './Avatar.svelte';
	import Icon from './Icon.svelte';

	let {
		userId,
		name,
		color,
		photo,
		size = 96,
		compact = false
	}: { userId: string; name: string; color: string; photo: string | null; size?: number; compact?: boolean } = $props();

	let busy = $state(false);
	let error = $state('');
	let bump = $state(0); // re-triggers the pop animation after each change
	let input: HTMLInputElement;

	/** Center-crop to a square and scale to 512px (EXIF rotation is applied by the browser). */
	async function toSquare(file: File): Promise<Blob> {
		const url = URL.createObjectURL(file);
		try {
			const img = new Image();
			img.src = url;
			await img.decode();
			const side = Math.min(img.naturalWidth, img.naturalHeight);
			const out = Math.min(512, side);
			const canvas = document.createElement('canvas');
			canvas.width = canvas.height = out;
			const ctx = canvas.getContext('2d')!;
			ctx.imageSmoothingQuality = 'high';
			ctx.drawImage(img, (img.naturalWidth - side) / 2, (img.naturalHeight - side) / 2, side, side, 0, 0, out, out);
			const webp = await new Promise<Blob | null>((r) => canvas.toBlob(r, 'image/webp', 0.86));
			if (webp && webp.type === 'image/webp') return webp;
			return (await new Promise<Blob | null>((r) => canvas.toBlob(r, 'image/jpeg', 0.88)))!;
		} finally {
			URL.revokeObjectURL(url);
		}
	}

	async function send(method: 'PUT' | 'DELETE', body?: Blob) {
		busy = true;
		error = '';
		try {
			const r = await fetch(`/api/users/${userId}/avatar`, { method, body });
			if (!r.ok) throw new Error((await r.json().catch(() => null))?.message ?? `Erro ${r.status}`);
			await invalidateAll();
			bump++;
		} catch (e) {
			error = (e as Error).message;
		} finally {
			busy = false;
		}
	}

	async function picked(e: Event) {
		const file = (e.currentTarget as HTMLInputElement).files?.[0];
		(e.currentTarget as HTMLInputElement).value = '';
		if (!file) return;
		try {
			await send('PUT', await toSquare(file));
		} catch {
			error = 'Não foi possível abrir essa imagem. Tente outra (JPG ou PNG).';
			busy = false;
		}
	}
</script>

<div class="editor" class:compact>
	<button type="button" class="pic" onclick={() => input.click()} disabled={busy} aria-label="Trocar a foto de {name}">
		{#key bump}
			<span class="pop"><Avatar {name} {color} {photo} {size} /></span>
		{/key}
		<span class="cam" class:busy><Icon name="camera" size={compact ? 14 : 18} /></span>
	</button>
	<input bind:this={input} type="file" accept="image/*" onchange={picked} hidden />
	{#if !compact}
		<div class="actions">
			<button type="button" class="btn small secondary" onclick={() => input.click()} disabled={busy}>
				{busy ? 'Salvando…' : photo ? 'Trocar foto' : 'Adicionar foto'}
			</button>
			{#if photo}
				<button type="button" class="link" onclick={() => send('DELETE')} disabled={busy}>Remover</button>
			{/if}
		</div>
	{/if}
	{#if error}<p class="error small" role="alert">{error}</p>{/if}
</div>

<style>
	.editor { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; }
	.pic { position: relative; padding: 0; border: 0; background: none; cursor: pointer; border-radius: 50%; }
	.pic:disabled { cursor: progress; }
	.pop { display: block; animation: pop-in 0.5s var(--bounce); }
	.cam {
		position: absolute; right: -2px; bottom: -2px; display: grid; place-items: center; width: 32px; height: 32px; border-radius: 50%;
		background: var(--sun); color: #4a3410; border: 3px solid var(--surface); box-shadow: 0 2px 0 var(--sun-dark);
	}
	.compact .cam { width: 24px; height: 24px; border-width: 2px; }
	.cam.busy { animation: wiggle 0.5s ease-in-out infinite; }
	.actions { display: flex; gap: 10px; align-items: center; }
	.link { background: none; border: 0; color: var(--danger); font-weight: 800; text-decoration: underline; cursor: pointer; min-height: 38px; }
	.error { width: 100%; margin: 0; }
</style>
