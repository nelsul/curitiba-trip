<script lang="ts">
	import { enhance } from '$app/forms';
	import AvatarEditor from '$lib/components/AvatarEditor.svelte';
	import Icon from '$lib/components/Icon.svelte';
	let { data, form } = $props();
	const PALETTE = ['#2F5A40', '#C4747E', '#3E6E9A', '#7A4A2E', '#8A5BB0', '#D08A2E', '#2E8A8A', '#B0465E', '#5B7A2E', '#4E5BA6'];
	const nextColor = $derived(PALETTE[data.users.length % PALETTE.length]);
</script>

<svelte:head><title>Pessoas · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<div class="title-row"><span class="title-icon"><Icon name="people" size={26} /></span><h1>Pessoas</h1></div>
	<p class="muted">Só quem está nesta lista consegue entrar. Toque na foto de alguém para trocar. Quando a noiva ou o noivo curte um post, a pessoa vê um efeito especial.</p>
	{#if form?.error}<p class="error" role="alert">{form.error}</p>{/if}
	{#if form?.added}<p role="status">{form.added} foi adicionado(a). Já pode entrar com o e-mail.</p>{/if}

	<ul class="list">
		{#each data.users as u (u.id)}
			<li class="card">
				<div class="head">
					<AvatarEditor userId={u.id} name={u.name} color={u.color} photo={u.photo} size={60} compact />
					<div class="grow">
						<strong class="nm">{u.name}</strong>
						<p class="small muted">{u.email}{u.is_admin ? ' · admin' : ''} · {u.items} {u.items === 1 ? 'item' : 'itens'}</p>
					</div>
				</div>
				<form method="POST" action="?/editar" use:enhance={() => async ({ update }) => update({ reset: false })} class="edit">
					<input type="hidden" name="id" value={u.id} />
					<input name="name" value={u.name} aria-label="Nome de {u.name}" />
					<input type="color" name="color" value={u.color} aria-label="Cor de {u.name}" />
					<button class="btn small secondary">Salvar</button>
				</form>
				<form method="POST" action="?/noivos" use:enhance={() => async ({ update }) => update({ reset: false })} class="edit">
					<input type="hidden" name="id" value={u.id} />
					<label class="couple small"><Icon name="ring" size={16} /> Casando?
						<select name="couple" value={u.couple ?? ''} onchange={(e) => e.currentTarget.form?.requestSubmit()}>
							<option value="">Não</option><option value="noiva">Noiva</option><option value="noivo">Noivo</option>
						</select>
					</label>
				</form>
				{#if u.items === 0 && u.id !== data.me.id}
					<form method="POST" action="?/remover" use:enhance={({ cancel }) => { if (!confirm(`Remover ${u.name}?`)) cancel(); }}>
						<input type="hidden" name="id" value={u.id} />
						<button class="link">Remover</button>
					</form>
				{/if}
			</li>
		{/each}
	</ul>

	<form method="POST" action="?/adicionar" use:enhance class="card add">
		<h2>Adicionar pessoa</h2>
		<label>Nome <input name="name" required maxlength="60" /></label>
		<label>E-mail <input name="email" type="email" required /></label>
		<label class="inline">Cor <input type="color" name="color" value={nextColor} /></label>
		<button class="btn">Adicionar</button>
	</form>
</main>

<style>
	.list { list-style: none; padding: 0; display: grid; gap: 10px; margin: 16px 0; }
	.list li { display: grid; gap: 10px; }
	.head { display: flex; gap: 14px; align-items: center; }
	.head :global(.editor) { flex: none; }
	.nm { font: 600 1.15rem var(--font-display); }
	.edit { display: flex; gap: 8px; align-items: center; }
	.edit input:not([type='color']) { flex: 1; min-width: 0; }
	.grow { flex: 1; min-width: 0; }
	.grow p { margin: 4px 0 0; overflow-wrap: anywhere; }
	input[type='color'] { width: 44px; height: 44px; padding: 2px; border: 1px solid var(--line); border-radius: 8px; background: var(--surface); flex: none; }
	.add { display: grid; gap: 10px; }
	.couple { display: flex; align-items: center; gap: 8px; font-weight: 800; }
	.couple select { width: auto; min-height: 40px; }
	.add h2 { margin: 0; }
	.add label { display: grid; gap: 4px; font-weight: 600; }
	.add .inline { display: flex; align-items: center; gap: 10px; }
	.link { background: none; border: 0; color: var(--danger); text-decoration: underline; cursor: pointer; min-height: 36px; padding: 0; margin-top: 6px; }
</style>
