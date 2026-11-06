<script lang="ts">
	import { enhance } from '$app/forms';
	import Icon from '$lib/components/Icon.svelte';
	let { form } = $props();
	let busy = $state(false);
	const step = $derived(form?.step ?? 'email');
	const submit = () => {
		busy = true;
		return async ({ update }: { update: () => Promise<void> }) => {
			await update();
			busy = false;
		};
	};
</script>

<svelte:head><title>Entrar · Viagem a Curitiba</title></svelte:head>

<main class="login">
	<div class="passport">
		<div class="clouds" aria-hidden="true"><span></span><span></span><span></span></div>
		<span class="plane" aria-hidden="true"><Icon name="plane" size={34} stroke={1.4} /></span>
		<p class="kicker">Passaporte da viagem</p>
		<h1>Curitiba</h1>
		<p class="dates">11 – 18 de novembro · 2026</p>
		<span class="seal" aria-hidden="true"><Icon name="leaf" size={30} stroke={2} /></span>
	</div>
	<p class="intro">Fotos, vídeos e lugares de todo mundo, num diário só.</p>

	<div class="card form-card">
		{#if step === 'email'}
			<form method="POST" action="?/enviar" use:enhance={submit}>
				<label for="email">Seu e-mail</label>
				<input id="email" name="email" type="email" autocomplete="email" inputmode="email" required value={form?.email ?? ''} />
				{#if form?.error}<p class="error" role="alert">{form.error}</p>{/if}
				<button class="btn sun block" disabled={busy}>{busy ? 'Enviando…' : 'Receber código por e-mail'}</button>
			</form>
		{:else}
			<form method="POST" action="?/verificar" use:enhance={submit}>
				<p>Enviamos um código de 6 números para <strong>{form?.email}</strong>.</p>
				<input type="hidden" name="email" value={form?.email} />
				<label for="code">Código</label>
				<!-- svelte-ignore a11y_autofocus -->
				<input id="code" name="code" type="text" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9 ]*" maxlength="7" required autofocus class="code" />
				{#if form?.error}<p class="error" role="alert">{form.error}</p>{/if}
				<button class="btn sun block" disabled={busy}>{busy ? 'Embarcando…' : 'Embarcar'}</button>
			</form>
			<form method="POST" action="?/enviar" use:enhance={submit} class="resend">
				<input type="hidden" name="email" value={form?.email} />
				<button class="link">Não chegou? Enviar de novo</button>
				<p class="muted small">Olhe também a caixa de spam.</p>
			</form>
		{/if}
	</div>
</main>

<style>
	.login { max-width: 420px; margin: 0 auto; padding: calc(32px + env(safe-area-inset-top)) 16px 32px; }
	.passport {
		position: relative; overflow: hidden; text-align: center; color: #fff6dc; padding: 34px 20px 28px; border-radius: 26px;
		background: radial-gradient(circle at 30% 20%, #2aa0a8, #18737a 70%); box-shadow: 0 6px 0 #0f5a60, 0 16px 30px rgb(0 0 0 / 0.15);
		border: 3px solid #0f5a60; animation: pop-in 0.6s var(--bounce) both;
	}
	.passport::after { content: ''; position: absolute; inset: 10px; border: 2px dashed rgb(255 246 220 / 0.45); border-radius: 18px; pointer-events: none; }
	.kicker { margin: 0; font-weight: 800; letter-spacing: 0.2em; text-transform: uppercase; font-size: 0.72rem; opacity: 0.9; }
	h1 { color: #fff6dc; font-size: 3rem; margin: 6px 0 2px; text-shadow: 0 3px 0 rgb(0 0 0 / 0.15); }
	.dates { margin: 0; font-weight: 700; }
	.seal { display: inline-grid; place-items: center; width: 58px; height: 58px; margin-top: 14px; border-radius: 50%; background: var(--sun); color: #4a3410; box-shadow: 0 4px 0 var(--sun-dark); animation: wiggle 3s ease-in-out infinite; }
	.plane { position: absolute; top: 18px; left: -40px; color: #fff; animation: cross 7s linear infinite; }
	.plane :global(svg) { fill: #fff; rotate: 90deg; }
	@keyframes cross { from { transform: translateX(0) translateY(10px); } to { transform: translateX(520px) translateY(-14px); } }
	.clouds span { position: absolute; width: 70px; height: 22px; border-radius: 999px; background: rgb(255 255 255 / 0.18); animation: drift 12s linear infinite; }
	.clouds span:nth-child(1) { top: 60px; left: 10%; }
	.clouds span:nth-child(2) { top: 120px; left: 60%; width: 90px; animation-duration: 16s; }
	.clouds span:nth-child(3) { bottom: 26px; left: 25%; width: 50px; animation-duration: 10s; }
	@keyframes drift { 50% { transform: translateX(24px); } }
	.intro { text-align: center; margin: 18px 8px; font-weight: 700; color: var(--muted); }
	form { display: grid; gap: 12px; }
	label { font-weight: 800; font-family: var(--font-display); }
	.code { font-size: 1.7rem; letter-spacing: 0.35em; text-align: center; font-family: var(--font-display); }
	.resend { margin-top: 14px; text-align: center; gap: 0; }
	.link { background: none; border: 0; color: var(--leaf); font-weight: 800; text-decoration: underline; cursor: pointer; min-height: 44px; }
	p { margin: 0; }
	.form-card { animation: pop-in 0.5s 0.15s var(--bounce) both; }
</style>
