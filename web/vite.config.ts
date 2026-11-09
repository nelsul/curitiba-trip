import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],
	build: {
		// maplibre-gl is ~1 MB minified (~280 KB gzipped) in one piece; it's already loaded only when a map is shown
		chunkSizeWarningLimit: 1200
	}
});
