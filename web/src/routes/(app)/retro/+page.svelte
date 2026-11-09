<script lang="ts">
	import { invalidate } from '$app/navigation';
	import Icon from '$lib/components/Icon.svelte';
	import Countdown from '$lib/components/Countdown.svelte';
	import MediaGrid from '$lib/components/MediaGrid.svelte';
	import Story from '$lib/components/Story.svelte';
	import { api } from '$lib/roteiro-client';

	let { data } = $props();
	const byId = $derived(new Map(data.persons.map((p) => [p.id, p])));
	const started = $derived(Date.now() >= new Date(data.weddingAt).getTime());
	let playing = $state(false);

	// ── admin: pick and order ──
	let editing = $state(false);
	let order = $state<string[]>([]);
	let picking = $state(false);
	let busy = $state(false);
	const mediaById = $derived(new Map(data.all.map((m) => [m.id, m])));
	function edit() {
		order = data.items.map((m) => m.id);
		editing = true;
	}
	const move = (i: number, d: number) => {
		const j = i + d;
		if (j < 0 || j >= order.length) return;
		const o = [...order];
		[o[i], o[j]] = [o[j], o[i]];
		order = o;
	};
	async function save() {
		busy = true;
		try {
			await api('PUT', '/api/admin/retro', { mediaIds: order });
			await invalidate('app:retro');
			editing = false;
		} catch (e) {
			alert((e as Error).message);
		} finally {
			busy = false;
		}
	}
</script>

<svelte:head><title>Retrospectiva · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<div class="title-row"><span class="title-icon"><Icon name="sparkle" size={26} /></span><h1>Retrospectiva</h1></div>

	{#if !started}
		<Countdown big />
		<p class="muted">Depois do casamento, aqui aparecem os melhores momentos da viagem, escolhidos a dedo, um atrás do outro.</p>
	{:else if data.items.length}
		<button class="play card" onclick={() => (playing = true)}>
			{#if data.items[0].image}<img src={data.items[0].image} alt="" />{/if}
			<span class="ov">
				<span class="pl"><Icon name="play" size={34} /></span>
				<strong>Ver a retrospectiva</strong>
				<span class="small">{data.items.length} momentos</span>
			</span>
		</button>
	{:else}
		<div class="card empty"><Icon name="sparkle" size={40} /><p>A retrospectiva está sendo preparada. Volte daqui a pouco!</p></div>
	{/if}

	{#if data.me.isAdmin}
		<section class="admin card">
			<h2>Só para administradores</h2>
			{#if !editing}
				<p class="small muted">{data.items.length} {data.items.length === 1 ? 'item escolhido' : 'itens escolhidos'}. {started ? '' : 'Todo mundo vê depois que a contagem acaba.'}</p>
				<div class="row">
					<button class="btn sun" onclick={edit}><Icon name="sparkle" size={18} /> Escolher e ordenar</button>
					{#if data.items.length}<button class="btn secondary" onclick={() => (playing = true)}><Icon name="play" size={18} /> Pré-visualizar</button>{/if}
				</div>
			{:else}
				<ol class="order">
					{#each order as id, i (id)}
						{@const m = mediaById.get(id)}
						<li>
							<span class="n">{i + 1}</span>
							{#if m?.thumb ?? m?.image}<img src={m?.thumb ?? m?.image} alt="" />{/if}
							<span class="grow small">{m?.caption || (m?.kind === 'video' ? 'Vídeo' : 'Foto')} · {byId.get(m?.userId ?? '')?.name ?? ''}</span>
							<button class="ib" onclick={() => move(i, -1)} disabled={i === 0} aria-label="Subir"><Icon name="up" size={18} /></button>
							<button class="ib" onclick={() => move(i, 1)} disabled={i === order.length - 1} aria-label="Descer"><Icon name="down" size={18} /></button>
							<button class="ib" onclick={() => (order = order.filter((x) => x !== id))} aria-label="Tirar"><Icon name="close" size={18} /></button>
						</li>
					{:else}
						<li class="muted small">Nada escolhido ainda.</li>
					{/each}
				</ol>
				<button class="btn secondary block" onclick={() => (picking = !picking)}><Icon name="grid" size={18} /> {picking ? 'Fechar fotos' : 'Escolher fotos e vídeos'}</button>
				{#if picking}<p class="small muted">Toque para pôr ou tirar; a ordem é a dos toques.</p><MediaGrid media={data.all} selecting bind:selected={order} max={300} onopen={() => {}} />{/if}
				<div class="row">
					<button class="btn secondary" onclick={() => (editing = false)}>Cancelar</button>
					<button class="btn sun" onclick={save} disabled={busy}>{busy ? 'Salvando…' : 'Salvar'}</button>
				</div>
			{/if}
		</section>
	{/if}
</main>

{#if playing}<Story items={data.items} persons={byId} onclose={() => (playing = false)} />{/if}

<style>
	.play { position: relative; display: block; width: 100%; aspect-ratio: 4 / 5; padding: 0; overflow: hidden; cursor: pointer; border-color: var(--sun); }
	.play img { width: 100%; height: 100%; object-fit: cover; display: block; filter: brightness(0.6); }
	.ov { position: absolute; inset: 0; display: grid; place-content: center; justify-items: center; gap: 6px; color: #fff; background: radial-gradient(circle, transparent, rgb(0 0 0 / 0.4)); }
	.ov strong { font: 600 1.6rem var(--font-display); }
	.pl { display: grid; place-items: center; width: 76px; height: 76px; border-radius: 50%; background: var(--sun); color: var(--on-sun); animation: bob 3s ease-in-out infinite; }
	.pl :global(svg) { fill: currentColor; }
	.empty { display: grid; justify-items: center; gap: 8px; text-align: center; color: var(--muted); }
	.empty p { margin: 0; }
	.admin { margin-top: 20px; display: grid; gap: 10px; }
	.admin h2 { margin: 0; font-size: 1.1rem; }
	.admin p { margin: 0; }
	.row { display: flex; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }
	.order { list-style: none; margin: 0; padding: 0; display: grid; gap: 6px; max-height: 50vh; overflow-y: auto; }
	.order li { display: flex; align-items: center; gap: 6px; }
	.order img { width: 44px; height: 44px; border-radius: 8px; object-fit: cover; flex: none; }
	.n { width: 24px; text-align: center; font-weight: 800; color: var(--sun); flex: none; }
	.grow { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.ib { flex: none; width: 40px; height: 40px; border: 2px solid var(--line); border-radius: 12px; background: var(--surface-2); color: var(--ink); display: grid; place-items: center; cursor: pointer; }
	.ib:disabled { opacity: 0.35; }
</style>
