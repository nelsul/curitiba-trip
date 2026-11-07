// Generates web/src/tokens.css, ios/CuritibaTrip/DesignSystem/Theme.swift and the Android Tokens.kt from design/tokens.json.
// `--check` exits 1 if the generated files are out of date (used by CI).
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const t = JSON.parse(readFileSync(join(root, 'design/tokens.json'), 'utf8'));
const kebab = (s) => s.replace(/([a-z])([A-Z0-9])/g, '$1-$2').toLowerCase();
const header = 'GENERATED from design/tokens.json by design/build-tokens.mjs. Do not edit by hand.';

const css = `/* ${header} */
:root {
${Object.entries(t.color).map(([k, v]) => `\t--${kebab(k)}: ${v};`).join('\n')}

	--radius: ${t.radius.card}px;
	--radius-sm: ${t.radius.small}px;
	--font-body: ${t.font.body.web};
	--font-display: ${t.font.display.web};
	--bounce: cubic-bezier(${t.motion.bounce.join(', ')});
}
`;

const hex = (h) => {
	const n = parseInt(h.slice(1), 16);
	return [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((x) => (x / 255).toFixed(3));
};
const swift = `// ${header}
import SwiftUI

extension Color {
${Object.entries(t.color).map(([k, v]) => { const [r, g, b] = hex(v); return `\tstatic let ${k} = Color(red: ${r}, green: ${g}, blue: ${b}) // ${v}`; }).join('\n')}
}

enum Radius {
${Object.entries(t.radius).map(([k, v]) => `\tstatic let ${k}: CGFloat = ${v}`).join('\n')}
}

/** Height of the solid "chunky" shadow under cards, buttons and chips (pt). */
enum Depth {
${Object.entries(t.shadow).map(([k, v]) => `\tstatic let ${k}: CGFloat = ${v}`).join('\n')}
}

enum FontFamily {
	static let display = "${t.font.display.ios}"
	static let body = "${t.font.body.ios}"
}
`;

const kotlin = `// ${header}
package com.nelsul.curitibatrip.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

object Palette {
${Object.entries(t.color).map(([k, v]) => `\tval ${k} = Color(0xFF${v.slice(1).toUpperCase()})`).join('\n')}
}

object Radius {
${Object.entries(t.radius).map(([k, v]) => `\tval ${k} = ${v}.dp`).join('\n')}
}

/** Height of the solid "chunky" shadow under cards, buttons and chips. */
object Depth {
${Object.entries(t.shadow).map(([k, v]) => `\tval ${k} = ${v}.dp`).join('\n')}
}
`;

const targets = [
	[join(root, 'web/src/tokens.css'), css],
	[join(root, 'ios/CuritibaTrip/DesignSystem/Theme.swift'), swift],
	[join(root, 'android/app/src/main/java/com/nelsul/curitibatrip/ui/theme/Tokens.kt'), kotlin]
];
const check = process.argv.includes('--check');
let stale = false;
for (const [file, content] of targets) {
	const current = existsSync(file) ? readFileSync(file, 'utf8') : null;
	if (current === content) continue;
	if (check) {
		console.error(`stale: ${file.replace(root + '/', '')}. Run: node design/build-tokens.mjs`);
		stale = true;
	} else {
		writeFileSync(file, content);
		console.log(`wrote ${file.replace(root + '/', '')}`);
	}
}
if (stale) process.exit(1);
if (check) console.log('design tokens up to date');
