import { error } from '@sveltejs/kit';
import { GetObjectCommand } from '@aws-sdk/client-s3';
import { inArray } from 'drizzle-orm';
import { db, media } from '$lib/server/db';
import { r2 } from '$lib/server/r2';
import { zipStream, type ZipEntry } from '$lib/server/zip';
import type { RequestHandler } from './$types';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/**
 * "Baixar" with several photos/videos picked: one ZIP with their originals (full quality, their own names),
 * streamed from storage as it downloads. `?ids=a,b,c` (up to 100). Browsers block many separate downloads in a row.
 */
export const GET: RequestHandler = async ({ url }) => {
	const ids = [...new Set((url.searchParams.get('ids') ?? '').split(',').filter((i) => UUID.test(i)))].slice(0, 100);
	if (!ids.length) error(400, 'Nenhum item.');
	const rows = await db()
		.select({ id: media.id, key: media.originalKey, name: media.originalName, size: media.sizeBytes, status: media.status, takenAt: media.takenAt, createdAt: media.createdAt })
		.from(media)
		.where(inArray(media.id, ids));
	const ready = rows
		.filter((r) => r.key && r.status !== 'uploading')
		.sort((a, b) => ids.indexOf(a.id) - ids.indexOf(b.id));
	if (!ready.length) error(404, 'Os originais ainda não chegaram.');

	const { s3, bucket } = r2();
	const used = new Map<string, number>();
	const entries: ZipEntry[] = ready.map((r) => {
		// same name twice (IMG_0001.jpg from two phones): "IMG_0001 (2).jpg"
		const base = (r.name || 'arquivo').replace(/[/\\\\]/g, '_');
		const n = (used.get(base) ?? 0) + 1;
		used.set(base, n);
		const dot = base.lastIndexOf('.');
		const name = n === 1 ? base : dot > 0 ? `${base.slice(0, dot)} (${n})${base.slice(dot)}` : `${base} (${n})`;
		return {
			name,
			size: Number(r.size) || 0,
			date: r.takenAt ?? r.createdAt,
			body: async () => {
				const obj = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: r.key! }));
				return obj.Body as unknown as AsyncIterable<Uint8Array>;
			}
		};
	});

	const day = new Date().toISOString().slice(0, 10);
	return new Response(zipStream(entries), {
		headers: {
			'content-type': 'application/zip',
			'content-disposition': `attachment; filename="curitiba-originais-${day}.zip"`,
			'cache-control': 'no-store'
		}
	});
};
