<script lang="ts">
	import AvatarEditor from '$lib/components/AvatarEditor.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import { loc, startSharing, stopSharing } from '$lib/location.svelte';
	let { data } = $props();
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
</style>
