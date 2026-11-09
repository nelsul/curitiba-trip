// Share frames: up to 9 photos laid out on one image with a frame, for Instagram and WhatsApp.
// The iOS (Features/Feed/Frames.swift) and Android (feature/feed/Frames.kt) apps draw the same layout:
// keep the numbers here and there in sync.

export type FrameStyle = 'polaroid' | 'passaporte' | 'noite' | 'casamento' | 'postal' | 'filme' | 'ingresso' | 'por-do-sol' | 'araucaria';
export type FrameFormat = 'post' | 'story';
/**
 * Decoration drawn on top of the background (sizes in the 1080 px wide image):
 * line: a rounded border 22 px in · airmail: red/blue diagonal stripes around the edge, 24 px ·
 * film: sprocket holes down both sides · ticket: a dashed tear line above the title with half-circle notches ·
 * dots: a dotted border 30 px in.
 */
export type FrameDeco = 'none' | 'line' | 'airmail' | 'film' | 'ticket' | 'dots';

export const FRAME_MAX = 9;

export type FrameStyleSpec = {
	label: string;
	/** background; with bg2, a top-to-bottom gradient */
	bg: string;
	bg2?: string;
	card: string;
	title: string;
	sub: string;
	/** color of the decoration */
	line: string | null;
	deco: FrameDeco;
	radius: number;
	text: [string, string];
};

export const FRAME_STYLES: Record<FrameStyle, FrameStyleSpec> = {
	polaroid: { label: 'Polaroid', bg: '#ffffff', card: '#eeeeee', title: '#1d2a45', sub: '#3a4d78', line: null, deco: 'none', radius: 6, text: ['Curitiba', '11 a 18 de novembro de 2026'] },
	passaporte: { label: 'Passaporte', bg: '#18737a', card: '#0f5a60', title: '#fff6dc', sub: '#f6d36b', line: '#fff6dc', deco: 'line', radius: 18, text: ['Viagem a Curitiba', '11–18 · novembro · 2026'] },
	noite: { label: 'Noite', bg: '#1d2a45', card: '#27375a', title: '#f6d36b', sub: '#f4eed6', line: null, deco: 'none', radius: 22, text: ['Curitiba', '11 a 18 de novembro de 2026'] },
	casamento: { label: 'Casamento', bg: '#fff6dc', card: '#f2e6c4', title: '#f08bb0', sub: '#1d2a45', line: '#f08bb0', deco: 'line', radius: 18, text: ['Casamento', '14 de novembro de 2026'] },
	postal: { label: 'Cartão-postal', bg: '#fbf3df', card: '#efe3c2', title: '#2f5aa8', sub: '#d9534f', line: '#d9534f', deco: 'airmail', radius: 6, text: ['Lembranças de Curitiba', '11 a 18 de novembro de 2026'] },
	filme: { label: 'Filme', bg: '#141414', card: '#262626', title: '#f4eed6', sub: '#f6d36b', line: '#f4eed6', deco: 'film', radius: 4, text: ['Curitiba', '11 a 18 · nov · 2026'] },
	ingresso: { label: 'Ingresso', bg: '#f6d36b', card: '#e9c24f', title: '#1d2a45', sub: '#9a4a1e', line: '#1d2a45', deco: 'ticket', radius: 14, text: ['Curitiba', 'Embarque 11/11 · Volta 18/11'] },
	'por-do-sol': { label: 'Pôr do sol', bg: '#f7a35c', bg2: '#7b3f8f', card: '#c8677a', title: '#fff6dc', sub: '#fff6dc', line: null, deco: 'none', radius: 24, text: ['Curitiba', '11 a 18 de novembro de 2026'] },
	araucaria: { label: 'Araucária', bg: '#2f5a40', card: '#244a34', title: '#f6d36b', sub: '#e8f1d8', line: '#8fc47a', deco: 'dots', radius: 18, text: ['Curitiba', 'Terra das araucárias · 2026'] }
};

/** The subtitle when "Local e data" is on: "Jardim Botânico · 14 de novembro". */
export const frameCaption = (place: string, day: string) => [place.trim(), day].filter(Boolean).join(' · ');

export const FRAME_SIZE: Record<FrameFormat, { w: number; h: number; label: string }> = {
	post: { w: 1080, h: 1350, label: 'Post (4:5)' },
	story: { w: 1080, h: 1920, label: 'Story (9:16)' }
};

/** How many photos go in each row, top to bottom. */
export const FRAME_ROWS: Record<number, number[]> = {
	1: [1], 2: [1, 1], 3: [1, 2], 4: [2, 2], 5: [2, 3], 6: [2, 2, 2], 7: [2, 2, 3], 8: [3, 2, 3], 9: [3, 3, 3]
};

export const FRAME_PAD = 56;
export const FRAME_FOOTER = 200;
export const FRAME_GAP = 14;

export type Cell = { x: number; y: number; w: number; h: number };

/** Where each photo goes (same math in the apps). */
export function frameCells(n: number, format: FrameFormat): Cell[] {
	const { w: W, h: H } = FRAME_SIZE[format];
	const rows = FRAME_ROWS[Math.max(1, Math.min(FRAME_MAX, n))];
	const aw = W - 2 * FRAME_PAD;
	const ah = H - 2 * FRAME_PAD - FRAME_FOOTER;
	const rh = (ah - FRAME_GAP * (rows.length - 1)) / rows.length;
	const cells: Cell[] = [];
	rows.forEach((count, r) => {
		const cw = (aw - FRAME_GAP * (count - 1)) / count;
		for (let c = 0; c < count; c++) cells.push({ x: FRAME_PAD + c * (cw + FRAME_GAP), y: FRAME_PAD + r * (rh + FRAME_GAP), w: cw, h: rh });
	});
	return cells;
}

function roundRect(g: CanvasRenderingContext2D, c: Cell, r: number) {
	g.beginPath();
	g.roundRect(c.x, c.y, c.w, c.h, r);
}

/** Text centered at the baseline, shrunk to fit the width if it's too long. */
function fitText(g: CanvasRenderingContext2D, text: string, weight: number, size: number, family: string, y: number, maxW: number) {
	g.font = `${weight} ${size}px ${family}`;
	const w = g.measureText(text).width;
	if (w > maxW) g.font = `${weight} ${Math.floor((size * maxW) / w)}px ${family}`;
	g.fillText(text, g.canvas.width / 2, y);
}

/** The decoration on top of the background (same shapes and sizes in the apps). */
function drawDeco(g: CanvasRenderingContext2D, s: FrameStyleSpec, W: number, H: number) {
	if (!s.line) return;
	g.save();
	switch (s.deco) {
		case 'line':
			g.strokeStyle = s.line;
			g.lineWidth = 4;
			roundRect(g, { x: 22, y: 22, w: W - 44, h: H - 44 }, 30);
			g.stroke();
			break;
		case 'airmail': {
			// 45° stripes every 120 px: red 40, gap 20, blue 40, gap 20; then the inside is painted back
			for (let x = -H; x < W + H; x += 120) {
				for (const [dx, color] of [[0, '#d9534f'], [60, '#2f5aa8']] as const) {
					g.fillStyle = color;
					g.beginPath();
					g.moveTo(x + dx, 0);
					g.lineTo(x + dx + 40, 0);
					g.lineTo(x + dx + 40 - H, H);
					g.lineTo(x + dx - H, H);
					g.closePath();
					g.fill();
				}
			}
			g.fillStyle = s.bg;
			g.fillRect(24, 24, W - 48, H - 48);
			break;
		}
		case 'film':
			g.fillStyle = s.line;
			for (let y = 30; y + 40 <= H - 20; y += 70) {
				roundRect(g, { x: 15, y, w: 26, h: 40 }, 6);
				g.fill();
				roundRect(g, { x: W - 41, y, w: 26, h: 40 }, 6);
				g.fill();
			}
			break;
		case 'ticket': {
			const y = H - FRAME_PAD - FRAME_FOOTER + 26;
			g.strokeStyle = s.line;
			g.lineWidth = 4;
			g.setLineDash([18, 14]);
			g.beginPath();
			g.moveTo(44, y);
			g.lineTo(W - 44, y);
			g.stroke();
			g.fillStyle = s.line;
			for (const x of [0, W]) {
				g.beginPath();
				g.arc(x, y, 30, 0, Math.PI * 2);
				g.fill();
			}
			break;
		}
		case 'dots': {
			g.fillStyle = s.line;
			const inset = 30;
			const dot = (x: number, y: number) => {
				g.beginPath();
				g.arc(x, y, 6, 0, Math.PI * 2);
				g.fill();
			};
			const nx = Math.round((W - 2 * inset) / 34), ny = Math.round((H - 2 * inset) / 34);
			for (let i = 0; i <= nx; i++) {
				const x = inset + ((W - 2 * inset) * i) / nx;
				dot(x, inset);
				dot(x, H - inset);
			}
			for (let i = 1; i < ny; i++) {
				const y = inset + ((H - 2 * inset) * i) / ny;
				dot(inset, y);
				dot(W - inset, y);
			}
			break;
		}
	}
	g.restore();
}

/**
 * Draws the frame with the photos (already loaded) on the canvas.
 * `caption` replaces the style's subtitle (the "Local e data" option).
 */
export function drawFrame(canvas: HTMLCanvasElement, photos: CanvasImageSource[], style: FrameStyle, format: FrameFormat, caption?: string | null) {
	const s = FRAME_STYLES[style];
	const { w: W, h: H } = FRAME_SIZE[format];
	canvas.width = W;
	canvas.height = H;
	const g = canvas.getContext('2d')!;
	if (s.bg2) {
		const grad = g.createLinearGradient(0, 0, 0, H);
		grad.addColorStop(0, s.bg);
		grad.addColorStop(1, s.bg2);
		g.fillStyle = grad;
	} else g.fillStyle = s.bg;
	g.fillRect(0, 0, W, H);
	drawDeco(g, s, W, H);
	const cells = frameCells(photos.length, format);
	photos.forEach((img, i) => {
		const c = cells[i];
		const iw = (img as HTMLImageElement).naturalWidth || (img as HTMLCanvasElement).width;
		const ih = (img as HTMLImageElement).naturalHeight || (img as HTMLCanvasElement).height;
		g.save();
		roundRect(g, c, s.radius);
		g.fillStyle = s.card;
		g.fill();
		g.clip();
		// cover: fill the cell, cropping the middle
		const k = Math.max(c.w / iw, c.h / ih);
		g.drawImage(img, c.x + (c.w - iw * k) / 2, c.y + (c.h - ih * k) / 2, iw * k, ih * k);
		g.restore();
	});
	g.textAlign = 'center';
	g.textBaseline = 'alphabetic';
	const maxW = W - 2 * FRAME_PAD - 40;
	g.fillStyle = s.title;
	fitText(g, s.text[0], 600, 76, 'Fredoka, Nunito, sans-serif', H - FRAME_PAD - 92, maxW);
	g.fillStyle = s.sub;
	fitText(g, caption || s.text[1], 800, 34, 'Nunito, sans-serif', H - FRAME_PAD - 34, maxW);
}

export function loadImage(src: string) {
	return new Promise<HTMLImageElement>((ok, fail) => {
		const img = new Image();
		img.onload = () => ok(img);
		img.onerror = () => fail(new Error('Não foi possível carregar uma das fotos.'));
		img.src = src;
	});
}
