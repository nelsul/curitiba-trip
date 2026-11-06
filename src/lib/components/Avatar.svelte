<script lang="ts">
	import { initials } from '$lib/format';
	let { name, color, size = 32 }: { name: string; color: string; size?: number } = $props();
</script>

<span class="avatar" style:background={color} style:width="{size}px" style:height="{size}px" style:font-size="{size * 0.38}px" aria-hidden="true">{initials(name)}</span>
