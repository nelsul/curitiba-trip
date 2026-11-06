import { fmtTime } from './format';

const W = 540; // CSS px; rendered at 2x → 1080x720 image
const H = 360;

/**
 * Loads a cross-origin image so the canvas stays exportable. Fetched with CORS and no cache:
 * the same R2 URL is usually already cached from a plain <img> (without CORS headers),
 * which would make a crossOrigin <img> fail.
 */
async function loadImage(src: string) {
	const r = await fetch(src, { mode: 'cors', cache: 'no-store' });
	if (!r.ok) throw new Error(`foto ${r.status}`);
	return createImageBitmap(await r.blob());
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
	ctx.beginPath();
	ctx.roundRect(x, y, w, h, r);
}

/**
 * Draws a picture of the trip map at a check-in: island-styled map (off-screen MapLibre),
 * the person's pin with their photo, a time label and the map attribution.
 */
export async function makeCheckinSnapshot(o: {
	lat: number;
	lng: number;
	color: string;
	name: string;
	photo?: string | null;
	at: string | number | Date;
}): Promise<Blob> {
	const [{ default: ml }, , { islandStyle }] = await Promise.all([
		import('maplibre-gl'),
		import('maplibre-gl/dist/maplibre-gl.css'),
		import('./map-style')
	]);

	const box = document.createElement('div');
	Object.assign(box.style, { position: 'fixed', left: '-10000px', top: '0', width: `${W}px`, height: `${H}px`, pointerEvents: 'none' });
	document.body.append(box);
	const map = new ml.Map({
		container: box,
		style: await islandStyle(false),
		center: [o.lng, o.lat],
		zoom: 16,
		interactive: false,
		attributionControl: false,
		pixelRatio: 2,
		fadeDuration: 0,
		canvasContextAttributes: { preserveDrawingBuffer: true }
	});

	try {
		await new Promise<void>((resolve, reject) => {
			const t = setTimeout(() => reject(new Error('mapa demorou demais')), 20_000);
			map.once('idle', () => {
				clearTimeout(t);
				resolve();
			});
			map.once('error', (e) => {
				clearTimeout(t);
				reject(e.error ?? new Error('erro no mapa'));
			});
		});

		const S = 2;
		const out = document.createElement('canvas');
		out.width = W * S;
		out.height = H * S;
		const ctx = out.getContext('2d')!;
		ctx.drawImage(map.getCanvas(), 0, 0, out.width, out.height);
		ctx.scale(S, S);

		// soft vignette so the pin pops
		const v = ctx.createRadialGradient(W / 2, H / 2, 80, W / 2, H / 2, W * 0.7);
		v.addColorStop(0, 'rgba(255,252,240,0)');
		v.addColorStop(1, 'rgba(90,69,48,0.22)');
		ctx.fillStyle = v;
		ctx.fillRect(0, 0, W, H);

		// pin: tip exactly on the check-in point (map center)
		const tipX = W / 2, tipY = H / 2;
		const r = 30, headY = tipY - 58;
		ctx.fillStyle = 'rgba(0,0,0,0.25)';
		ctx.beginPath();
		ctx.ellipse(tipX, tipY + 2, 16, 5, 0, 0, Math.PI * 2);
		ctx.fill();
		ctx.beginPath();
		ctx.moveTo(tipX, tipY);
		ctx.bezierCurveTo(tipX - 14, tipY - 18, tipX - r, headY + r * 0.6, tipX - r, headY);
		ctx.arc(tipX, headY, r, Math.PI, 0);
		ctx.bezierCurveTo(tipX + r, headY + r * 0.6, tipX + 14, tipY - 18, tipX, tipY);
		ctx.closePath();
		ctx.fillStyle = o.color;
		ctx.fill();
		ctx.lineWidth = 4;
		ctx.strokeStyle = '#fff';
		ctx.stroke();

		// face (or initial) inside the pin head
		const fr = r - 6;
		let drewPhoto = false;
		if (o.photo) {
			try {
				const face = await loadImage(o.photo);
				ctx.save();
				ctx.beginPath();
				ctx.arc(tipX, headY, fr, 0, Math.PI * 2);
				ctx.clip();
				ctx.drawImage(face, tipX - fr, headY - fr, fr * 2, fr * 2);
				ctx.restore();
				drewPhoto = true;
			} catch {
				/* fall back to the initial */
			}
		}
		if (!drewPhoto) {
			ctx.fillStyle = '#fff';
			ctx.beginPath();
			ctx.arc(tipX, headY, fr, 0, Math.PI * 2);
			ctx.fill();
			ctx.fillStyle = o.color;
			ctx.font = "600 26px Fredoka, 'Nunito', system-ui, sans-serif";
			ctx.textAlign = 'center';
			ctx.textBaseline = 'middle';
			ctx.fillText(o.name.slice(0, 1).toUpperCase(), tipX, headY + 1);
		}

		// label: "Nelson · 19:56"
		const label = `${o.name} · ${fmtTime(o.at)}`;
		ctx.font = "600 17px Fredoka, 'Nunito', system-ui, sans-serif";
		ctx.textAlign = 'left';
		ctx.textBaseline = 'middle';
		const lw = ctx.measureText(label).width + 28;
		roundRect(ctx, 14, H - 50, lw, 36, 18);
		ctx.fillStyle = '#fffcf0';
		ctx.fill();
		ctx.lineWidth = 2.5;
		ctx.strokeStyle = '#e7dbb8';
		ctx.stroke();
		ctx.fillStyle = '#5a4530';
		ctx.fillText(label, 28, H - 31);

		// attribution (required by the map data license)
		ctx.font = "700 9px 'Nunito', system-ui, sans-serif";
		ctx.textAlign = 'right';
		ctx.fillStyle = 'rgba(90,69,48,0.75)';
		ctx.fillText('© OpenStreetMap · OpenFreeMap', W - 8, H - 8);

		const webp = await new Promise<Blob | null>((res) => out.toBlob(res, 'image/webp', 0.85));
		if (webp && webp.type === 'image/webp') return webp;
		return (await new Promise<Blob | null>((res) => out.toBlob(res, 'image/jpeg', 0.86)))!;
	} finally {
		map.remove();
		box.remove();
	}
}

/** Generates and uploads the picture for a check-in. Never throws: the feed falls back to the plain banner. */
export async function attachSnapshot(checkinId: string, o: Parameters<typeof makeCheckinSnapshot>[0]) {
	try {
		const blob = await makeCheckinSnapshot(o);
		const r = await fetch(`/api/checkins/${checkinId}/snapshot`, { method: 'PUT', body: blob });
		if (!r.ok) return null;
		return ((await r.json()).snapshot as string | null) ?? null;
	} catch (e) {
		console.warn('[snapshot]', e);
		return null;
	}
}
