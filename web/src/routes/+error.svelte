<script lang="ts">
	import { page } from '$app/state';
</script>

<svelte:head><title>Erro · Viagem a Curitiba</title></svelte:head>

<main class="page narrow">
	<h1>{page.status === 404 ? 'Não encontrado' : 'Algo deu errado'}</h1>
	<p>{page.error?.message}</p>
	<a class="btn" href="/">Voltar para a linha do tempo</a>
</main>
