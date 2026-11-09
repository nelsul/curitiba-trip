// Browser helpers for editing the Roteiro.

/** JSON request to the API; throws an Error with the server's Portuguese message. */
export async function api<T = unknown>(method: string, url: string, body?: unknown): Promise<T> {
	const r = await fetch(url, {
		method,
		headers: body === undefined ? undefined : { 'content-type': 'application/json' },
		body: body === undefined ? undefined : JSON.stringify(body)
	});
	const data = await r.json().catch(() => ({}));
	if (!r.ok) throw new Error(data.message || 'Não foi possível salvar. Tente de novo.');
	return data as T;
}

/** Shrinks a photo to at most `max` px on its longest side, as JPEG (fast uploads, still sharp on phones). */
export async function resizeImage(file: File, max = 1600): Promise<Blob> {
	const bmp = await createImageBitmap(file);
	const scale = Math.min(1, max / Math.max(bmp.width, bmp.height));
	const w = Math.round(bmp.width * scale), h = Math.round(bmp.height * scale);
	const canvas = document.createElement('canvas');
	canvas.width = w;
	canvas.height = h;
	canvas.getContext('2d')!.drawImage(bmp, 0, 0, w, h);
	bmp.close();
	return new Promise((resolve, reject) =>
		canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('Não foi possível ler a foto.'))), 'image/jpeg', 0.85)
	);
}

/** Uploads one photo to a place → { id, url } */
export async function uploadPlacePhoto(placeId: string, file: File) {
	const blob = await resizeImage(file);
	const r = await fetch(`/api/roteiro/places/${placeId}/photos`, { method: 'POST', headers: { 'content-type': 'image/jpeg' }, body: blob });
	const data = await r.json().catch(() => ({}));
	if (!r.ok) throw new Error(data.message || 'Não foi possível enviar a foto.');
	return data as { id: string; url: string };
}
