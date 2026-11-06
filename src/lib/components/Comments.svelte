<script lang="ts">
	import { enhance } from '$app/forms';
	import Avatar from './Avatar.svelte';
	import Icon from './Icon.svelte';
	import { fmtAgo } from '$lib/format';

	type C = { id: string; body: string; at: string; userId: string; name: string; color: string };
	let { comments, meId, error = '' }: { comments: C[]; meId: string; error?: string } = $props();
	let body = $state('');
	let busy = $state(false);
</script>

<section class="comments">
	<h2><Icon name="chat" size={22} /> Comentários</h2>
	{#if comments.length === 0}<p class="muted">Ninguém comentou ainda.</p>{/if}
	<ul>
		{#each comments as c (c.id)}
			<li>
				<Avatar name={c.name} color={c.color} size={30} />
				<div class="say">
					<p class="meta"><strong>{c.name}</strong> <span class="muted small">{fmtAgo(c.at)}</span></p>
					<p class="text">{c.body}</p>
				</div>
				{#if c.userId === meId}
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
		<textarea id="body" name="body" bind:value={body} placeholder="Escreva um comentário…" rows="2" required></textarea>
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
</style>
