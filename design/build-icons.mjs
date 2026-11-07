// Exports the web icon set (web/src/lib/components/Icon.svelte) as vector template images for the iOS
// asset catalog, so both apps draw identical icons. Run after changing the icons.
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = readFileSync(join(root, 'web/src/lib/components/Icon.svelte'), 'utf8');
const icons = Object.fromEntries([...src.matchAll(/^\t\t(\w+): '([^']+)'/gm)].map((m) => [m[1], m[2]]));
const dir = join(root, 'ios/CuritibaTrip/Resources/Assets.xcassets/Icons');
rmSync(dir, { recursive: true, force: true });
mkdirSync(dir, { recursive: true });
writeFileSync(join(dir, 'Contents.json'), JSON.stringify({ info: { author: 'xcode', version: 1 }, properties: { 'provides-namespace': true } }, null, 2));
for (const [name, d] of Object.entries(icons)) {
	const set = join(dir, `${name}.imageset`);
	mkdirSync(set);
	writeFileSync(join(set, `${name}.svg`), `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="${d}"/></svg>\n`);
	writeFileSync(join(set, 'Contents.json'), JSON.stringify({
		images: [{ filename: `${name}.svg`, idiom: 'universal' }],
		info: { author: 'xcode', version: 1 },
		properties: { 'preserves-vector-representation': true, 'template-rendering-intent': 'template' }
	}, null, 2));
}
console.log(`exported ${Object.keys(icons).length} icons: ${Object.keys(icons).join(', ')}`);
