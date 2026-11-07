<script lang="ts">
	import { initials } from '$lib/format';
	let { name, color, photo = null, size = 32 }: { name: string; color: string; photo?: string | null; size?: number } = $props();
	let broken = $state(false);
	$effect(() => {
		void photo;
		broken = false;
	});
</script>

{#if photo && !broken}
	<img class="avatar photo" src={photo} alt="" width={size} height={size} style:width="{size}px" style:height="{size}px" style:border-color={color} onerror={() => (broken = true)} />
{:else}
	<span class="avatar" style:background={color} style:width="{size}px" style:height="{size}px" style:font-size="{size * 0.38}px" aria-hidden="true">{initials(name)}</span>
{/if}

<style>
	.photo { object-fit: cover; padding: 0; background: var(--track); border-width: 3px; border-style: solid; }
</style>
