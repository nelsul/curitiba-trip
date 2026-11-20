<script lang="ts">
	import { enhance } from '$app/forms';
	import Icon from '$lib/components/Icon.svelte';
	import { fmtTime } from '$lib/format';

	let { data, form } = $props();
	let busy = $state(false);
</script>

<svelte:head><title>Visitante · Viagem a Curitiba</title></svelte:head>

<main class="page narrow visit">
	<div class="title-row"><span class="title-icon"><Icon name="ticket" size={26} /></span><h1>Visitante</h1></div>

	{#if data.visiting}
		<div class="card stack">
			<p>Você está vendo o diário como visitante, convidado por <strong>{data.visiting.by}</strong>, até as <strong>{fmtTime(data.visiting.until)}</strong>.</p>
			<a class="btn sun block" href="/">Ver o diário</a>
			<form method="POST" action="?/sair"><button class="btn secondary block">Sair</button></form>
		</div>
	{:else}
		<form class="card stack" method="POST" action="?/entrar" use:enhance={() => { busy = true; return async ({ update }) => { await update(); busy = false; }; }}>
			{#if data.ended && !form?.error}<p class="note" role="status">A visita acabou: os códigos valem 2 horas. Peça um novo a quem te convidou.</p>{/if}
			<p>Alguém da viagem te passou um código? Com ele você vê o diário (fotos e vídeos) por 2 horas.</p>
			<label for="code" class="small muted">Código de visitante</label>
			<input id="code" name="code" type="text" autocomplete="off" autocapitalize="characters" spellcheck="false" maxlength="12" required
				placeholder="ABCD-EFGH" class="code" />
			{#if form?.error}<p class="error" role="alert">{form.error}</p>{/if}
			<button class="btn sun block" disabled={busy}>{busy ? 'Entrando…' : 'Entrar'}</button>
			<a class="small center" href="/login">É da viagem? Entre com seu nome</a>
		</form>
	{/if}
</main>

<style>
	.visit { padding-top: calc(32px + env(safe-area-inset-top)); }
	.stack { display: grid; gap: 12px; }
	.stack p { margin: 0; }
	.code { font: 600 1.6rem var(--font-display); text-align: center; letter-spacing: 0.12em; text-transform: uppercase; }
	.note { background: var(--surface-2); border-radius: 12px; padding: 10px 12px; }
	.center { text-align: center; }
</style>
