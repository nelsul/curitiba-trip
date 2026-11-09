<script lang="ts">
	import { onMount } from 'svelte';
	import Avatar from '$lib/components/Avatar.svelte';
	import Icon, { type IconName } from '$lib/components/Icon.svelte';
	import { fmtAgo } from '$lib/format';
	import { unread } from '$lib/notifications.svelte';

	let { data } = $props();
	const byId = $derived(new Map(data.persons.map((p) => [p.id, p])));
	const icon: Record<string, IconName> = { post: 'camera', checkin: 'pin', comment: 'chat', like: 'heart', mention: 'chat', split: 'wallet', paid: 'check' };
	const color: Record<string, string> = { post: 'var(--sea)', checkin: 'var(--leaf)', comment: 'var(--sky)', like: 'var(--berry)', mention: 'var(--plum)', split: 'var(--sun)', paid: 'var(--leaf)' };
	const href = (n: (typeof data.items)[number]) => (n.cotinha ? '/cotinha' : n.mediaId ? `/m/${n.mediaId}` : n.checkinId ? `/c/${n.checkinId}` : '/');

	// opening the page reads everything
	onMount(() => {
		unread.count = 0;
		fetch('/api/notifications/seen', { method: 'POST' }).catch(() => {});
	});
</script>

<svelte:head><title>Notificações · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<div class="title-row"><span class="title-icon"><Icon name="bell" size={26} /></span><h1>Notificações</h1></div>
	<p class="muted small intro">O que o grupo fez nos últimos 14 dias: posts, check-ins, comentários e curtidas nos seus posts, quando te marcam e as cotinhas.</p>

	<ul class="list">
		{#each data.items as n (n.id)}
			{@const p = byId.get(n.userId)}
			<li>
				<a class="note card" class:unread={n.unread} href={href(n)}>
					<span class="who">
						<Avatar name={p?.name ?? '?'} color={p?.color ?? '#888'} photo={p?.photo} size={44} />
						<span class="kind" style:--c={color[n.kind]}><Icon name={icon[n.kind]} size={13} stroke={2.6} /></span>
					</span>
					<span class="txt">
						<strong>{n.text}</strong>
						{#if n.body}<span class="body small">{n.body}</span>{/if}
						<span class="small muted">{fmtAgo(n.at)}</span>
					</span>
					{#if n.image}<img src={n.image} alt="" loading="lazy" />{/if}
					{#if n.unread}<i class="dot" aria-label="Nova"></i>{/if}
				</a>
			</li>
		{:else}
			<li class="card empty"><Icon name="bell" size={40} /><p>Nada por aqui ainda.</p></li>
		{/each}
	</ul>
</main>

<style>
	.intro { margin: 0 0 12px; }
	.list { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
	.note { position: relative; display: flex; align-items: center; gap: 12px; padding: 10px 12px; text-decoration: none; color: var(--ink); }
	.note.unread { border-color: var(--sea); background: color-mix(in srgb, var(--sea) 10%, var(--surface)); }
	.who { position: relative; flex: none; }
	.kind { position: absolute; right: -4px; bottom: -4px; display: grid; place-items: center; width: 22px; height: 22px; border-radius: 50%; background: var(--c); color: #fff; border: 2px solid var(--surface); }
	.txt { flex: 1; min-width: 0; display: grid; gap: 1px; }
	.txt strong { font-weight: 800; overflow-wrap: anywhere; }
	.body { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	img { flex: none; width: 48px; height: 48px; border-radius: 10px; object-fit: cover; }
	.dot { position: absolute; top: 10px; right: 10px; width: 9px; height: 9px; border-radius: 50%; background: var(--coral); }
	.empty { display: grid; justify-items: center; gap: 8px; text-align: center; color: var(--muted); }
	.empty p { margin: 0; }
</style>
