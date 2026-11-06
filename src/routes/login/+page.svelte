<script lang="ts">
	import { enhance } from '$app/forms';
	import Icon from '$lib/components/Icon.svelte';
	import Avatar from '$lib/components/Avatar.svelte';
	let { data, form } = $props();
	let busy = $state<string | null>(null);
	let back = $state(false);
	const step = $derived(back ? 'pick' : (form?.step ?? 'pick'));
	const chosen = $derived(form && 'userId' in form ? data.persons.find((p) => p.id === form.userId) : undefined);
	const submit = (key: string) => () => {
		busy = key;
		back = false;
		return async ({ update }: { update: () => Promise<void> }) => {
			await update();
			busy = null;
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

	{#if step === 'pick'}
		<section class="form-card">
			<h2 class="who-title">Quem é você?</h2>
			{#if form?.error}<p class="error center" role="alert">{form.error}</p>{/if}
			<ul class="people">
				{#each data.persons as p, i (p.id)}
					<li style:animation-delay="{150 + i * 60}ms">
						<form method="POST" action="?/enviar" use:enhance={submit(p.id)}>
							<input type="hidden" name="userId" value={p.id} />
							<button class="person" disabled={busy !== null} aria-busy={busy === p.id} style:--c={p.color}>
								<Avatar name={p.name} color={p.color} photo={p.photo} size={64} />
								<span class="pname">{p.name}</span>
								{#if busy === p.id}<span class="sending small">Enviando…</span>{/if}
							</button>
						</form>
					</li>
				{/each}
			</ul>
			<p class="muted small center">Vamos mandar um código para o seu e-mail.</p>
		</section>
	{:else}
		<div class="card form-card">
			<div class="chosen">
				{#if chosen}<Avatar name={chosen.name} color={chosen.color} photo={chosen.photo} size={56} />{/if}
				<p>Oi{chosen ? `, ${chosen.name}` : ''}! Enviamos um código de 6 números para <strong>{form?.maskedEmail}</strong>.</p>
			</div>
			<form method="POST" action="?/verificar" use:enhance={submit('code')}>
				<input type="hidden" name="userId" value={form?.userId} />
				<input type="hidden" name="maskedEmail" value={form?.maskedEmail} />
				<label for="code">Código</label>
				<!-- svelte-ignore a11y_autofocus -->
				<input id="code" name="code" type="text" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9 ]*" maxlength="7" required autofocus class="code" />
				{#if form?.error}<p class="error" role="alert">{form.error}</p>{/if}
				<button class="btn sun block" disabled={busy !== null}>{busy === 'code' ? 'Embarcando…' : 'Embarcar'}</button>
			</form>
			<div class="resend">
				<form method="POST" action="?/enviar" use:enhance={submit('resend')}>
					<input type="hidden" name="userId" value={form?.userId} />
					<button class="link">Não chegou? Enviar de novo</button>
				</form>
				<p class="muted small">Olhe também a caixa de spam.</p>
				<button class="link" onclick={() => (back = true)}>Não é você? Trocar</button>
			</div>
		</div>
	{/if}
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
	.form-card form { display: grid; gap: 12px; }
	.who-title { text-align: center; margin: 4px 0 14px; }
	.center { text-align: center; }
	.people { list-style: none; padding: 0; margin: 0 0 14px; display: grid; grid-template-columns: repeat(auto-fill, minmax(96px, 1fr)); gap: 12px; }
	.people li { animation: pop-in 0.45s var(--bounce) both; }
	.people form { display: block; }
	.person {
		width: 100%; display: grid; justify-items: center; gap: 6px; padding: 14px 6px 10px; cursor: pointer;
		background: var(--surface); border: 2.5px solid var(--line); border-radius: 20px; box-shadow: 0 4px 0 var(--shadow);
		transition: transform 0.15s var(--bounce), border-color 0.15s;
	}
	.person:hover:not(:disabled) { transform: translateY(-3px) rotate(-1.5deg); border-color: var(--c); }
	.person:active:not(:disabled) { transform: translateY(2px); box-shadow: 0 1px 0 var(--shadow); }
	.person:disabled { cursor: default; }
	.person[aria-busy='true'] { border-color: var(--c); }
	.person[aria-busy='true'] :global(.avatar) { animation: bob 0.6s ease-in-out infinite; }
	.pname { font: 600 1.05rem var(--font-display); }
	.sending { color: var(--muted); font-weight: 800; margin-top: -4px; }
	.chosen { display: flex; gap: 12px; align-items: center; margin-bottom: 14px; }
	.chosen p { margin: 0; }
	label { font-weight: 800; font-family: var(--font-display); }
	.code { font-size: 1.7rem; letter-spacing: 0.35em; text-align: center; font-family: var(--font-display); }
	.resend { margin-top: 14px; text-align: center; display: grid; justify-items: center; }
	.link { background: none; border: 0; color: var(--leaf); font-weight: 800; text-decoration: underline; cursor: pointer; min-height: 44px; }
	p { margin: 0; }
	.form-card { animation: pop-in 0.5s 0.15s var(--bounce) both; }
</style>
