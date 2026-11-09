// Share frames: up to 9 photos laid out on one image with a frame, for Instagram and WhatsApp.
// The iOS (Features/Feed/Frames.swift) and Android (feature/feed/Frames.kt) apps draw the same layout:
// keep the numbers here and there in sync.

export type FrameStyle = 'polaroid' | 'passaporte' | 'noite' | 'casamento';
export type FrameFormat = 'post' | 'story';

export const FRAME_MAX = 9;

export const FRAME_STYLES: Record<FrameStyle, { label: string; bg: string; card: string; title: string; sub: string; line: string | null; radius: number; text: [string, string] }> = {
	polaroid: { label: 'Polaroid', bg: '#ffffff', card: '#eeeeee', title: '#1d2a45', sub: '#3a4d78', line: null, radius: 6, text: ['Curitiba', '11 a 18 de novembro de 2026'] },
	passaporte: { label: 'Passaporte', bg: '#18737a', card: '#0f5a60', title: '#fff6dc', sub: '#f6d36b', line: '#fff6dc', radius: 18, text: ['Viagem a Curitiba', '11–18 · novembro · 2026'] },
	noite: { label: 'Noite', bg: '#1d2a45', card: '#27375a', title: '#f6d36b', sub: '#f4eed6', line: null, radius: 22, text: ['Curitiba', '11 a 18 de novembro de 2026'] },
	casamento: { label: 'Casamento', bg: '#fff6dc', card: '#f2e6c4', title: '#f08bb0', sub: '#1d2a45', line: '#f08bb0', radius: 18, text: ['Casamento', '14 de novembro de 2026'] }
};

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

/** Draws the frame with the photos (already loaded) on the canvas. */
export function drawFrame(canvas: HTMLCanvasElement, photos: CanvasImageSource[], style: FrameStyle, format: FrameFormat) {
	const s = FRAME_STYLES[style];
	const { w: W, h: H } = FRAME_SIZE[format];
	canvas.width = W;
	canvas.height = H;
	const g = canvas.getContext('2d')!;
	g.fillStyle = s.bg;
	g.fillRect(0, 0, W, H);
	if (s.line) {
		g.strokeStyle = s.line;
		g.lineWidth = 4;
		roundRect(g, { x: 22, y: 22, w: W - 44, h: H - 44 }, 30);
		g.stroke();
	}
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
	g.fillStyle = s.title;
	g.font = `600 76px Fredoka, Nunito, sans-serif`;
	g.fillText(s.text[0], W / 2, H - FRAME_PAD - 92);
	g.fillStyle = s.sub;
	g.font = `800 34px Nunito, sans-serif`;
	g.fillText(s.text[1], W / 2, H - FRAME_PAD - 34);
}

export function loadImage(src: string) {
	return new Promise<HTMLImageElement>((ok, fail) => {
		const img = new Image();
		img.onload = () => ok(img);
		img.onerror = () => fail(new Error('Não foi possível carregar uma das fotos.'));
		img.src = src;
	});
}
