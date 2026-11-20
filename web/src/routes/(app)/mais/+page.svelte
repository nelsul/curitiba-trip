<script lang="ts">
	import AvatarEditor from '$lib/components/AvatarEditor.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import { enhance } from '$app/forms';
	import { page } from '$app/state';
	import { loc, startSharing, stopSharing } from '$lib/location.svelte';
	import { fmtTime } from '$lib/format';
	let { data, form } = $props();

	/** the code just made (shown once), unless it was ended since */
	const fresh = $derived(form?.newCode && data.guestCodes.some((c) => c.id === form.newCode.id) ? form.newCode : null);
	let copied = $state(false);
	async function share() {
		const c = fresh!;
		const text = `Veja o diário da nossa viagem a Curitiba: ${page.url.origin}/visitante com o código ${c.code} (vale até as ${fmtTime(c.expiresAt)}).`;
		try {
			if (navigator.share) await navigator.share({ text });
			else {
				await navigator.clipboard.writeText(text);
				copied = true;
				setTimeout(() => (copied = false), 2500);
			}
		} catch {
			/* cancelled */
		}
	}
</script>

<svelte:head><title>Mais · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<div class="title-row"><span class="title-icon"><Icon name="user" size={26} /></span><h1>Mais</h1></div>

	<section class="card me">
		<AvatarEditor userId={data.me.id} name={data.me.name} color={data.me.color} photo={data.me.photo} size={88} compact />
		<div class="me-info">
			<strong class="nm">{data.me.name}</strong>
			{#if data.me.isAdmin}<p class="small muted">Administrador</p>{/if}
			<p class="small muted">Toque na foto para trocar.</p>
		</div>
	</section>

	<section class="card stack">
		<h2>Localização</h2>
		<p>Enquanto o app estiver aberto, sua posição aparece no mapa para o grupo. Com o app fechado, nada é enviado (o navegador não permite).</p>
		{#if loc.error}<p class="error small">{loc.error}</p>{/if}
		<button class="btn" class:secondary={!loc.sharing} onclick={() => (loc.sharing ? stopSharing() : startSharing())}>
			{loc.sharing ? 'Parar de compartilhar' : 'Compartilhar minha localização'}
		</button>
	</section>

	<section class="card stack">
		<h2>Visitantes</h2>
		<p>Gere um código para alguém de fora ver o diário (fotos e vídeos) por 2 horas. Visitantes não veem o mapa, o roteiro nem a cotinha, e não podem enviar, curtir ou comentar.</p>
		{#if fresh}
			<div class="code-box">
				<span class="small muted">Código de visitante</span>
				<strong class="code">{fresh.code}</strong>
				<span class="small muted">Vale até as {fmtTime(fresh.expiresAt)}. Quem tiver o código entra em <strong>{page.url.host}/visitante</strong>.</span>
				<button class="btn sun" onclick={share}><Icon name="share" size={18} /> {copied ? 'Copiado!' : 'Enviar o convite'}</button>
			</div>
		{/if}
		<form method="POST" action="?/visitante" use:enhance><button class="btn" class:secondary={!!fresh}><Icon name="ticket" size={18} /> {fresh ? 'Gerar outro código' : 'Gerar código de visitante'}</button></form>
		{#if data.guestCodes.length}
			<ul class="codes">
				{#each data.guestCodes as c (c.id)}
					<li>
						<span class="small">Código de {fmtTime(c.createdAt)}, vale até as <strong>{fmtTime(c.expiresAt)}</strong></span>
						<form method="POST" action="?/encerrarVisitante" use:enhance><input type="hidden" name="id" value={c.id} /><button class="btn small secondary">Encerrar</button></form>
					</li>
				{/each}
			</ul>
		{/if}
	</section>

	<section class="card stack">
		<h2>Instalar no celular</h2>
		<p><strong>iPhone (Safari):</strong> toque em Compartilhar e depois em “Adicionar à Tela de Início”.</p>
		<p><strong>Android (Chrome):</strong> menu ⋮ e depois “Instalar app” ou “Adicionar à tela inicial”.</p>
	</section>

	<section class="stack">
		<a class="btn secondary" href="/retro"><Icon name="sparkle" size={18} /> Retrospectiva</a>
		{#if data.me.isAdmin}<a class="btn secondary" href="/admin">Gerenciar pessoas</a>{/if}
		<form method="POST" action="?/sair"><button class="btn secondary block">Sair</button></form>
	</section>
</main>

<style>
	section { margin-bottom: 16px; }
	.me { display: flex; gap: 16px; align-items: center; }
	.me-info { display: grid; gap: 2px; }
	.me p { margin: 0; }
	.nm { font-family: var(--font-display); font-weight: 600; font-size: 1.4rem; }
	.stack { display: grid; gap: 10px; }
	.stack p, .stack h2 { margin: 0; }
	.code-box { display: grid; gap: 6px; justify-items: center; text-align: center; padding: 14px; border-radius: 16px; background: var(--surface-2); border: 2px dashed var(--sun); }
	.code { font: 600 2rem var(--font-display); letter-spacing: 0.1em; color: var(--sun); user-select: all; }
	.codes { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
	.codes li { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
</style>
