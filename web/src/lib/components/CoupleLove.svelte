<script lang="ts">
	import { onMount } from 'svelte';
	import Icon from './Icon.svelte';
	import Avatar from './Avatar.svelte';
	import type { Person } from '$lib/types';

	type Like = { id: number; likerId: string; role: 'noivo' | 'noiva'; mediaId: string | null; checkinId: string | null; image: string | null };

	/**
	 * Special effect when the bride or groom liked one of my posts: shown once (the server remembers it was seen).
	 * Loads by itself when the app opens.
	 */
	let { persons }: { persons: Person[] } = $props();
	let likes = $state<Like[]>([]);

	onMount(async () => {
		try {
			const r = await fetch('/api/couple-likes');
			if (r.ok) likes = (await r.json()).likes;
		} catch {}
	});

	const first = $derived(likes[0]);
	const roles = $derived(new Set(likes.map((l) => l.role)));
	const who = $derived(roles.size > 1 ? 'Os noivos' : roles.has('noiva') ? 'A noiva' : 'O noivo');
	const likers = $derived([...new Set(likes.map((l) => l.likerId))].map((id) => persons.find((p) => p.id === id)).filter((p): p is Person => !!p));
	const posts = $derived(new Set(likes.map((l) => l.mediaId ?? l.checkinId)).size);
	const href = $derived(first ? (first.mediaId ? `/m/${first.mediaId}` : `/c/${first.checkinId}`) : '/');

	async function done() {
		const upTo = Math.max(...likes.map((l) => l.id));
		likes = [];
		await fetch('/api/couple-likes/seen', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ upTo }) }).catch(() => {});
	}
	const hearts = Array.from({ length: 26 }, (_, i) => ({ x: (i * 37) % 100, d: 2.6 + ((i * 7) % 10) / 4, delay: ((i * 13) % 20) / 10, s: 16 + ((i * 11) % 28) }));
</script>

{#if first}
	<div class="love" role="dialog" aria-modal="true" aria-labelledby="love-title">
		<div class="rain" aria-hidden="true">
			{#each hearts as h, i (i)}<span style:left="{h.x}%" style:animation-duration="{h.d}s" style:animation-delay="{h.delay}s"><Icon name={i % 4 ? 'heart' : 'ring'} size={h.s} /></span>{/each}
		</div>
		<div class="box">
			<div class="pics">
				{#if first.image}<img class="post" src={first.image} alt="" />{/if}
				<div class="avs">{#each likers as p (p.id)}<Avatar name={p.name} color={p.color} photo={p.photo} size={56} />{/each}</div>
				<span class="badge"><Icon name="heart" size={30} /></span>
			</div>
			<h2 id="love-title">{who} {roles.size > 1 ? 'curtiram' : 'curtiu'} {posts > 1 ? `${posts} posts seus` : 'seu post'}!</h2>
			<p>{likers.map((p) => p.name).join(' e ')} {likers.length > 1 ? 'deixaram' : 'deixou'} um coração para você.</p>
			<div class="row">
				<button class="btn secondary" onclick={done}>Fechar</button>
				<a class="btn sun" {href} onclick={done}>Ver o post</a>
			</div>
		</div>
	</div>
{/if}

<style>
	.love { position: fixed; inset: 0; z-index: 120; display: grid; place-items: center; padding: 16px; background: radial-gradient(circle, color-mix(in srgb, var(--berry) 45%, transparent), rgb(10 15 30 / 0.92)); animation: fade 0.4s both; }
	@keyframes fade { from { opacity: 0; } }
	.rain { position: absolute; inset: 0; overflow: hidden; pointer-events: none; }
	.rain span { position: absolute; top: -40px; color: var(--berry); animation: fall linear infinite; }
	.rain span:nth-child(3n) { color: var(--sun); }
	.rain :global(svg) { fill: currentColor; }
	@keyframes fall { to { transform: translateY(110vh) rotate(40deg); } }
	.box { position: relative; display: grid; gap: 10px; justify-items: center; text-align: center; max-width: 360px; padding: 24px 20px; border-radius: var(--radius); background: var(--bg); border: 3px solid var(--berry); box-shadow: 0 0 40px color-mix(in srgb, var(--berry) 60%, transparent); animation: pop-in 0.7s var(--bounce) both; }
	.pics { position: relative; display: grid; place-items: center; }
	.post { width: 180px; height: 180px; object-fit: cover; border-radius: 18px; border: 6px solid #fff; rotate: -4deg; }
	.avs { position: absolute; bottom: -18px; right: -22px; display: flex; }
	.avs :global(*) { border: 3px solid var(--bg); border-radius: 50%; }
	.badge { position: absolute; top: -18px; left: -18px; display: grid; place-items: center; width: 56px; height: 56px; border-radius: 50%; background: var(--berry); color: #fff; animation: beat 1s ease-in-out infinite; }
	.badge :global(svg) { fill: #fff; }
	@keyframes beat { 50% { transform: scale(1.2); } }
	h2 { margin: 14px 0 0; font-size: 1.5rem; color: var(--berry); }
	p { margin: 0; }
	.row { display: flex; gap: 8px; margin-top: 6px; }
</style>
