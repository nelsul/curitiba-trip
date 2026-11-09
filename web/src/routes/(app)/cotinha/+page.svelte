<script lang="ts">
	import { invalidate } from '$app/navigation';
	import { onMount } from 'svelte';
	import Avatar from '$lib/components/Avatar.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import { brl, equalParts, parseCents } from '$lib/money';
	import { fmtAgo } from '$lib/format';
	import { api } from '$lib/roteiro-client';

	let { data } = $props();
	const me = $derived(data.me.id);
	const byId = $derived(new Map(data.persons.map((p) => [p.id, p])));
	const name = (id: string) => (id === me ? 'Você' : (byId.get(id)?.name ?? 'Alguém'));
	const reload = () => invalidate('app:cotinha');

	/** what I owe others / what others owe me, still open */
	const iOwe = $derived(data.splits.reduce((a, s) => a + (s.payerId !== me ? s.shares.filter((x) => x.userId === me && !x.paidAt).reduce((b, x) => b + x.amountCents, 0) : 0), 0));
	const owedToMe = $derived(data.splits.reduce((a, s) => a + (s.payerId === me ? s.shares.filter((x) => x.userId !== me && !x.paidAt).reduce((b, x) => b + x.amountCents, 0) : 0), 0));
	let filter = $state<'abertas' | 'todas'>('abertas');
	/** Cotinhas, or what I owe grouped by who paid ("Por pessoa", to pay everything with one Pix) */
	let view = $state<'cotinhas' | 'pessoas'>('cotinhas');
	type Debt = { payerId: string; totalCents: number; pixKey: string; items: { id: string; title: string; amountCents: number; createdAt: string }[] };
	const debts = $derived.by(() => {
		const by = new Map<string, Debt>();
		for (const s of data.splits) {
			if (s.payerId === me) continue;
			const mine = s.shares.find((x) => x.userId === me && !x.paidAt);
			if (!mine) continue;
			const d = by.get(s.payerId) ?? by.set(s.payerId, { payerId: s.payerId, totalCents: 0, pixKey: '', items: [] }).get(s.payerId)!;
			d.totalCents += mine.amountCents;
			if (!d.pixKey && s.pixKey) d.pixKey = s.pixKey; // the newest one (the list is newest first)
			d.items.push({ id: s.id, title: s.title, amountCents: mine.amountCents, createdAt: s.createdAt });
		}
		return [...by.values()].sort((a, b) => b.totalCents - a.totalCents);
	});
	async function payAll(d: Debt) {
		if (!confirm(`Marcar como pago tudo o que você deve para ${name(d.payerId)} (${brl(d.totalCents)})?`)) return;
		try {
			await api('POST', '/api/splits/pay-all', { payerId: d.payerId });
			say(`Pronto! ${d.items.length === 1 ? 'A cotinha foi marcada' : `As ${d.items.length} cotinhas foram marcadas`} como paga${d.items.length === 1 ? '' : 's'}.`);
			await reload();
		} catch (err) {
			alert((err as Error).message);
		}
	}
	const open = (s: (typeof data.splits)[number]) => s.shares.some((x) => !x.paidAt);
	const shown = $derived(data.splits.filter((s) => filter === 'todas' || open(s)));

	// ── new cotinha ──
	let dialog = $state<HTMLDialogElement>();
	let title = $state('');
	let amount = $state('');
	let pix = $state('');
	let note = $state('');
	let who = $state<string[]>([]);
	let busy = $state(false);
	let error = $state('');
	const cents = $derived(parseCents(amount));
	const parts = $derived(cents && who.length ? equalParts(cents, who.length) : []);

	function startNew() {
		title = '';
		amount = '';
		pix = data.myPix;
		note = '';
		who = data.persons.map((p) => p.id);
		error = '';
		dialog?.showModal();
	}
	const toggle = (id: string) => (who = who.includes(id) ? who.filter((x) => x !== id) : [...who, id]);

	async function create(e: SubmitEvent) {
		e.preventDefault();
		if (!cents || cents <= 0) return (error = 'Valor inválido.');
		if (!who.length) return (error = 'Escolha quem divide.');
		busy = true;
		error = '';
		try {
			await api('POST', '/api/splits', { title, totalCents: cents, pixKey: pix, note, participants: who });
			dialog?.close();
			await reload();
		} catch (err) {
			error = (err as Error).message;
		} finally {
			busy = false;
		}
	}

	async function paid(splitId: string, userId: string, value: boolean) {
		try {
			await api('POST', `/api/splits/${splitId}/paid`, { userId, paid: value });
			await reload();
		} catch (err) {
			alert((err as Error).message);
		}
	}
	let toast = $state('');
	const say = (t: string) => {
		toast = t;
		setTimeout(() => (toast = ''), 2500);
	};
	async function remind(id: string) {
		try {
			await api('POST', `/api/splits/${id}/remind`);
			say('Lembrete enviado para quem ainda não pagou.');
			await reload();
		} catch (err) {
			alert((err as Error).message);
		}
	}
	async function remove(id: string, t: string) {
		if (!confirm(`Apagar a cotinha "${t}"?`)) return;
		try {
			await api('DELETE', `/api/splits/${id}`);
			await reload();
		} catch (err) {
			alert((err as Error).message);
		}
	}
	async function copy(text: string) {
		try {
			await navigator.clipboard.writeText(text);
			say('Chave Pix copiada!');
		} catch {
			prompt('Copie a chave Pix:', text);
		}
	}

	onMount(() => {
		const t = setInterval(() => document.visibilityState === 'visible' && reload(), 30_000);
		return () => clearInterval(t);
	});
</script>

<svelte:head><title>Cotinha · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<div class="title-row"><span class="title-icon"><Icon name="wallet" size={26} /></span><h1>Cotinha</h1></div>
	<p class="muted intro">Pagou algo para o grupo? Crie uma cotinha com sua chave Pix: cada um vê quanto deve e marca quando pagar.</p>

	<div class="totals">
		<div class="card tot owe"><span class="small">Você deve</span><strong>{brl(iOwe)}</strong></div>
		<div class="card tot get"><span class="small">Te devem</span><strong>{brl(owedToMe)}</strong></div>
	</div>

	<button class="btn sun block" onclick={startNew}><Icon name="plus" size={20} /> Nova cotinha</button>

	<div class="views" role="tablist" aria-label="Ver">
		<button role="tab" aria-selected={view === 'cotinhas'} onclick={() => (view = 'cotinhas')}><Icon name="wallet" size={18} /> Cotinhas</button>
		<button role="tab" aria-selected={view === 'pessoas'} onclick={() => (view = 'pessoas')}><Icon name="people" size={18} /> Por pessoa</button>
	</div>

	{#if view === 'pessoas'}
		<p class="muted small intro">Quanto você deve para cada pessoa, somando as cotinhas. Pague tudo de uma vez com um Pix só e marque “Paguei tudo”.</p>
		{#each debts as d (d.payerId)}
			{@const p = byId.get(d.payerId)}
			<article class="card split debt">
				<header>
					<Avatar name={p?.name ?? '?'} color={p?.color ?? '#888'} photo={p?.photo} size={44} />
					<div class="ttl"><h2>{name(d.payerId)}</h2><span class="small muted">{d.items.length} {d.items.length === 1 ? 'cotinha' : 'cotinhas'}</span></div>
					<strong class="total owe-total">{brl(d.totalCents)}</strong>
				</header>
				{#if d.pixKey}
					<button class="pix" onclick={() => copy(d.pixKey)} aria-label="Copiar a chave Pix {d.pixKey}">
						<span class="small muted">Pix de {name(d.payerId)} · toque para copiar</span>
						<span class="key">{d.pixKey}</span>
						<Icon name="copy" size={18} />
					</button>
				{/if}
				<ul class="items">
					{#each d.items as it (it.id)}<li><span>{it.title}</span><span class="small muted">{fmtAgo(it.createdAt)}</span><b>{brl(it.amountCents)}</b></li>{/each}
				</ul>
				<button class="btn sun block" onclick={() => payAll(d)}><Icon name="check" size={18} /> Paguei tudo · {brl(d.totalCents)}</button>
			</article>
		{:else}
			<div class="card empty-card"><Icon name="check" size={40} /><p>Você não deve nada para ninguém.</p></div>
		{/each}
	{:else}
	<div class="chips filter" role="tablist" aria-label="Mostrar">
		<button role="tab" class="chip" aria-selected={filter === 'abertas'} onclick={() => (filter = 'abertas')}>Em aberto</button>
		<button role="tab" class="chip" aria-selected={filter === 'todas'} onclick={() => (filter = 'todas')}>Todas</button>
	</div>

	{#each shown as s (s.id)}
		{@const payer = byId.get(s.payerId)}
		{@const mine = s.payerId === me}
		{@const myShare = s.shares.find((x) => x.userId === me)}
		{@const paidCount = s.shares.filter((x) => x.paidAt).length}
		<article class="card split" class:done={!open(s)}>
			<header>
				<Avatar name={payer?.name ?? '?'} color={payer?.color ?? '#888'} photo={payer?.photo} size={40} />
				<div class="ttl">
					<h2>{s.title}</h2>
					<span class="small muted">{mine ? 'Você pagou' : `${name(s.payerId)} pagou`} · {fmtAgo(s.createdAt)}</span>
				</div>
				<strong class="total">{brl(s.totalCents)}</strong>
			</header>

			{#if myShare && !mine}
				<div class="mine" class:ok={!!myShare.paidAt}>
					<span>{myShare.paidAt ? 'Você já pagou' : 'Sua parte'}</span>
					<strong>{brl(myShare.amountCents)}</strong>
				</div>
			{/if}

			{#if s.pixKey}
				<button class="pix" onclick={() => copy(s.pixKey)} aria-label="Copiar a chave Pix {s.pixKey}">
					<span class="small muted">{mine ? 'Sua chave Pix' : `Pix de ${name(s.payerId)}`} · toque para copiar</span>
					<span class="key">{s.pixKey}</span>
					<Icon name="copy" size={18} />
				</button>
			{/if}
			{#if s.note}<p class="note small">{s.note}</p>{/if}

			<div class="bar" aria-label="{paidCount} de {s.shares.length} pagaram"><i style:width="{(paidCount / s.shares.length) * 100}%"></i></div>
			<ul class="shares">
				{#each s.shares as x (x.userId)}
					{@const p = byId.get(x.userId)}
					{@const canMark = x.userId === me || mine || data.me.isAdmin}
					<li class:paid={!!x.paidAt}>
						<Avatar name={p?.name ?? '?'} color={p?.color ?? '#888'} photo={p?.photo} size={30} />
						<span class="nm">{name(x.userId)}{x.userId === s.payerId ? ' (pagou)' : ''}</span>
						<span class="amt">{brl(x.amountCents)}</span>
						{#if x.userId === s.payerId}
							<span class="state ok"><Icon name="check" size={16} /></span>
						{:else if canMark}
							<button class="state" class:ok={!!x.paidAt} aria-pressed={!!x.paidAt} onclick={() => paid(s.id, x.userId, !x.paidAt)}
								aria-label={x.paidAt ? `Desmarcar pagamento de ${name(x.userId)}` : `Marcar que ${name(x.userId)} pagou`}>
								{#if x.paidAt}<Icon name="check" size={16} /> Pago{:else}{x.userId === me ? 'Já paguei' : 'Pagou?'}{/if}
							</button>
						{:else}
							<span class="state" class:ok={!!x.paidAt}>{#if x.paidAt}<Icon name="check" size={16} />{:else}Falta{/if}</span>
						{/if}
					</li>
				{/each}
			</ul>

			{#if mine || data.me.isAdmin}
				<footer>
					{#if open(s) && mine}<button class="btn small secondary" onclick={() => remind(s.id)}><Icon name="bell" size={16} /> Cobrar quem falta</button>{/if}
					<button class="link" onclick={() => remove(s.id, s.title)}>Apagar</button>
				</footer>
			{/if}
		</article>
	{:else}
		<div class="card empty-card"><Icon name="wallet" size={40} /><p>{filter === 'abertas' ? 'Nenhuma cotinha em aberto.' : 'Nenhuma cotinha ainda.'}</p></div>
	{/each}
	{/if}
</main>

{#if toast}<p class="toast" role="status">{toast}</p>{/if}

<dialog bind:this={dialog} class="editor" aria-labelledby="new-split">
	<form onsubmit={create}>
		<header class="dh">
			<h2 id="new-split">Nova cotinha</h2>
			<button type="button" class="x" onclick={() => dialog?.close()} aria-label="Fechar"><Icon name="close" size={20} /></button>
		</header>
		<label><span class="label">O que foi</span><input bind:value={title} required maxlength="120" placeholder="Ex.: Mercado, Uber do aeroporto" /></label>
		<label><span class="label">Valor total (R$)</span><input bind:value={amount} required inputmode="decimal" placeholder="0,00" /></label>
		<label><span class="label">Sua chave Pix</span><input bind:value={pix} maxlength="140" placeholder="CPF, e-mail, celular ou chave aleatória" autocomplete="off" />
			<span class="small muted">Fica salva para as próximas cotinhas.</span></label>
		<fieldset>
			<legend class="label">Quem divide ({who.length})</legend>
			<div class="people">
				{#each data.persons as p (p.id)}
					{@const i = who.indexOf(p.id)}
					<label class="person" class:on={i >= 0}>
						<input type="checkbox" class="sr-only" checked={i >= 0} onchange={() => toggle(p.id)} />
						<Avatar name={p.name} color={p.color} photo={p.photo} size={30} />
						<span>{p.id === me ? 'Você' : p.name}</span>
						{#if i >= 0 && parts.length}<b>{brl(parts[i])}</b>{/if}
					</label>
				{/each}
			</div>
		</fieldset>
		<label><span class="label">Observação</span><textarea bind:value={note} rows="2" maxlength="1000" placeholder="Opcional"></textarea></label>
		{#if error}<p class="error small" role="alert">{error}</p>{/if}
		<footer class="df">
			<button type="button" class="btn secondary" onclick={() => dialog?.close()}>Cancelar</button>
			<button class="btn sun" disabled={busy}>{busy ? 'Criando…' : 'Criar e avisar'}</button>
		</footer>
	</form>
</dialog>

<style>
	.intro { margin: 0 0 12px; }
	.totals { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 12px; }
	.tot { display: grid; gap: 2px; padding: 12px 14px; }
	.tot strong { font: 600 1.4rem var(--font-display); }
	.owe strong { color: var(--coral); }
	.get strong { color: var(--leaf); }
	.filter { margin: 14px 0 10px; }
	.views { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin: 14px 0 4px; padding: 4px; background: var(--surface); border: 2.5px solid var(--line); border-radius: 999px; }
	.views button { display: inline-flex; align-items: center; justify-content: center; gap: 6px; min-height: 40px; border: 0; border-radius: 999px; background: none; color: var(--muted); font: 600 1rem var(--font-display); cursor: pointer; }
	.views button[aria-selected='true'] { background: var(--sea); color: var(--on-sea); }
	.debt { margin-top: 10px; }
	.owe-total { color: var(--coral); }
	.items { list-style: none; margin: 0; padding: 0; display: grid; gap: 6px; }
	.items li { display: grid; grid-template-columns: 1fr auto auto; gap: 10px; align-items: baseline; padding: 6px 0; border-bottom: 1.5px dashed var(--line); }
	.items li:last-child { border-bottom: 0; }
	.items b { font-variant-numeric: tabular-nums; }
	.split { display: grid; gap: 10px; margin-bottom: 14px; animation: pop-in 0.4s var(--bounce) both; }
	.split.done { opacity: 0.75; }
	.split header { display: flex; align-items: center; gap: 10px; }
	.ttl { display: grid; min-width: 0; flex: 1; }
	.ttl h2 { margin: 0; font-size: 1.15rem; overflow-wrap: anywhere; }
	.total { font: 600 1.25rem var(--font-display); color: var(--sun); white-space: nowrap; }
	.mine { display: flex; justify-content: space-between; align-items: center; padding: 8px 12px; border-radius: 14px; background: color-mix(in srgb, var(--coral) 22%, var(--surface)); font-weight: 800; }
	.mine.ok { background: color-mix(in srgb, var(--leaf) 22%, var(--surface)); }
	.mine strong { font: 600 1.2rem var(--font-display); }
	.pix { display: grid; grid-template-columns: 1fr auto; grid-template-rows: auto auto; column-gap: 8px; align-items: center; text-align: left; width: 100%; min-height: 44px; padding: 8px 12px; border: 2.5px dashed var(--sea); border-radius: 14px; background: none; color: var(--ink); cursor: pointer; }
	.pix .small { grid-column: 1; }
	.pix .key { grid-column: 1; font-weight: 800; overflow-wrap: anywhere; }
	.pix :global(svg) { grid-column: 2; grid-row: 1 / 3; color: var(--sea); }
	.note { margin: 0; white-space: pre-wrap; }
	.bar { height: 8px; border-radius: 999px; background: var(--track); overflow: hidden; }
	.bar i { display: block; height: 100%; background: var(--leaf); border-radius: 999px; transition: width 0.4s var(--bounce); }
	.shares { list-style: none; margin: 0; padding: 0; display: grid; gap: 6px; }
	.shares li { display: flex; align-items: center; gap: 8px; }
	.nm { flex: 1; min-width: 0; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.amt { font-weight: 800; font-variant-numeric: tabular-nums; }
	.state { display: inline-flex; align-items: center; justify-content: center; gap: 3px; min-width: 84px; min-height: 36px; padding: 0 10px; border-radius: 999px; border: 2px solid var(--line); background: var(--surface-2); color: var(--muted); font-weight: 800; font-size: 0.85rem; }
	button.state { cursor: pointer; color: var(--ink); border-color: var(--sea); }
	.state.ok { background: var(--leaf); border-color: var(--leaf); color: var(--on-leaf); }
	.split footer { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
	.link { background: none; border: 0; color: var(--danger); font-weight: 800; cursor: pointer; min-height: 44px; margin-left: auto; }
	.empty-card { display: grid; justify-items: center; gap: 8px; text-align: center; color: var(--muted); }
	.empty-card p { margin: 0; }
	.toast { position: fixed; z-index: 70; left: 50%; translate: -50% 0; bottom: calc(var(--nav-h) + 24px); background: var(--leaf); color: var(--on-leaf); font-weight: 800; padding: 8px 16px; border-radius: 999px; margin: 0; }
	.editor { width: min(520px, 100vw); max-width: 100vw; max-height: 100dvh; margin: auto; padding: 0; border: 2.5px solid var(--line); border-radius: var(--radius); background: var(--bg); color: var(--ink); }
	.editor::backdrop { background: rgb(10 15 30 / 0.6); }
	.editor form { display: grid; gap: 12px; padding: 0 16px 16px; }
	.dh { position: sticky; top: 0; display: flex; align-items: center; justify-content: space-between; padding: 14px 0 6px; background: var(--bg); z-index: 2; }
	.dh h2 { margin: 0; }
	.x { width: 44px; height: 44px; border: 0; border-radius: 50%; background: var(--surface); color: var(--ink); display: grid; place-items: center; cursor: pointer; }
	.label { display: block; font-weight: 800; font-size: 0.9rem; margin-bottom: 6px; }
	label { display: block; }
	fieldset { border: 0; margin: 0; padding: 0; min-width: 0; }
	.people { display: flex; flex-wrap: wrap; gap: 8px; }
	.person { display: inline-flex; align-items: center; gap: 6px; min-height: 44px; padding: 4px 12px 4px 4px; border: 2.5px dashed var(--line); border-radius: 999px; background: var(--surface); font-weight: 800; cursor: pointer; }
	.person.on { border-style: solid; border-color: var(--leaf); background: color-mix(in srgb, var(--leaf) 18%, var(--surface)); }
	.person b { color: var(--leaf); font-size: 0.85rem; }
	.person:focus-within { outline: 3px solid var(--sea); outline-offset: 2px; }
	.df { position: sticky; bottom: 0; display: flex; justify-content: flex-end; gap: 8px; padding-top: 8px; background: var(--bg); }
	@media (max-width: 600px) { .editor { width: 100vw; height: 100dvh; border-radius: 0; border: 0; } }
</style>
