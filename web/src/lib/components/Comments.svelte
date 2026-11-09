<script lang="ts">
	import { enhance } from '$app/forms';
	import Avatar from './Avatar.svelte';
	import Icon from './Icon.svelte';
	import { fmtAgo } from '$lib/format';
	import { mentionParts, mentionQuery, suggest } from '$lib/mentions';

	type C = { id: string; body: string; at: string; userId: string; name: string; color: string; photo: string | null };
	type P = { id: string; name: string; color: string; photo: string | null };
	let {
		comments,
		meId,
		isAdmin = false,
		persons = [],
		error = ''
	}: { comments: C[]; meId: string; isAdmin?: boolean; persons?: P[]; error?: string } = $props();
	let body = $state('');
	let busy = $state(false);

	// @mentions: suggestions for what's typed after "@"
	let box = $state<HTMLTextAreaElement>();
	let mention = $state<{ query: string; start: number } | null>(null);
	let active = $state(0);
	const options = $derived(mention ? suggest(persons.filter((p) => p.id !== meId), mention.query) : []);
	function onInput() {
		mention = box ? mentionQuery(body, box.selectionStart) : null;
		active = 0;
	}
	function pick(p: P) {
		if (!mention || !box) return;
		const end = mention.start + 1 + mention.query.length;
		body = `${body.slice(0, mention.start)}@${p.name} ${body.slice(end)}`;
		const caret = mention.start + p.name.length + 2;
		mention = null;
		requestAnimationFrame(() => {
			box?.focus();
			box?.setSelectionRange(caret, caret);
		});
	}
	function onKey(e: KeyboardEvent) {
		if (!options.length) return;
		if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
			e.preventDefault();
			active = (active + (e.key === 'ArrowDown' ? 1 : options.length - 1)) % options.length;
		} else if (e.key === 'Enter' || e.key === 'Tab') {
			e.preventDefault();
			pick(options[active]);
		} else if (e.key === 'Escape') mention = null;
	}
</script>

<section class="comments" id="comentarios">
	<h2><Icon name="chat" size={22} /> Comentários</h2>
	{#if comments.length === 0}<p class="muted">Ninguém comentou ainda.</p>{/if}
	<ul>
		{#each comments as c (c.id)}
			<li>
				<Avatar name={c.name} color={c.color} photo={c.photo} size={34} />
				<div class="say">
					<p class="meta"><strong>{c.name}</strong> <span class="muted small">{fmtAgo(c.at)}</span></p>
					<p class="text">{#each mentionParts(c.body, persons) as part, i (i)}{#if part.mention}<b class="at">{part.text}</b>{:else}{part.text}{/if}{/each}</p>
				</div>
				{#if c.userId === meId || isAdmin}
					<form method="POST" action="?/apagarComentario" use:enhance>
						<input type="hidden" name="id" value={c.id} />
						<button class="del" aria-label="Apagar comentário">×</button>
					</form>
				{/if}
			</li>
		{/each}
	</ul>
	<form
		method="POST"
		action="?/comentar"
		class="new"
		use:enhance={() => {
			busy = true;
			return async ({ update, result }) => {
				await update({ reset: false });
				if (result.type === 'success') body = '';
				busy = false;
			};
		}}
	>
		<label for="body" class="sr-only">Seu comentário</label>
		<div class="field">
			{#if options.length}
				<ul class="suggest card" role="listbox" aria-label="Marcar alguém">
					{#each options as p, i (p.id)}
						<li role="option" aria-selected={i === active}>
							<button type="button" onmousedown={(e) => e.preventDefault()} onclick={() => pick(p)}>
								<Avatar name={p.name} color={p.color} photo={p.photo} size={28} /> {p.name}
							</button>
						</li>
					{/each}
				</ul>
			{/if}
			<textarea id="body" name="body" bind:this={box} bind:value={body} oninput={onInput} onkeydown={onKey} onblur={() => setTimeout(() => (mention = null), 150)}
				placeholder="Escreva um comentário… (use @ para marcar alguém)" rows="2" required></textarea>
		</div>
		{#if error}<p class="error small">{error}</p>{/if}
		<button class="btn sea" disabled={busy || !body.trim()}>Comentar</button>
	</form>
</section>

<style>
	.comments { margin-top: 24px; }
	ul { list-style: none; padding: 0; margin: 0 0 12px; display: grid; gap: 12px; }
	li { display: grid; grid-template-columns: auto 1fr auto; gap: 10px; align-items: start; }
	li p { margin: 0; }
	h2 { display: flex; align-items: center; gap: 8px; }
	li { animation: pop-in 0.4s var(--bounce) both; }
	.say { position: relative; background: var(--surface); border: 2.5px solid var(--line); border-radius: 18px; padding: 8px 12px; box-shadow: 0 3px 0 var(--shadow); }
	.say::before { content: ''; position: absolute; left: -9px; top: 12px; width: 14px; height: 14px; background: var(--surface); border-left: 2.5px solid var(--line); border-bottom: 2.5px solid var(--line); transform: rotate(45deg); border-radius: 0 0 0 4px; }
	.meta strong { font-family: var(--font-display); font-weight: 600; }
	.text { white-space: pre-wrap; overflow-wrap: anywhere; }
	.del { border: 0; background: none; color: var(--muted); font-size: 1.3rem; min-width: 36px; min-height: 36px; cursor: pointer; }
	.new { display: grid; gap: 8px; justify-items: end; }
	.field { position: relative; width: 100%; }
	.field textarea { width: 100%; }
	.at { color: var(--sea); font-weight: 800; }
	.suggest { position: absolute; bottom: calc(100% + 6px); left: 0; right: 0; z-index: 10; list-style: none; margin: 0; padding: 6px; display: grid; gap: 2px; }
	.suggest button { display: flex; align-items: center; gap: 10px; width: 100%; min-height: 44px; padding: 4px 8px; border: 0; border-radius: 12px; background: none; color: var(--ink); font-weight: 800; text-align: left; cursor: pointer; }
	.suggest li[aria-selected='true'] button, .suggest button:hover { background: var(--surface-2); }
</style>
