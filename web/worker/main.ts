import PgBoss from 'pg-boss';
import { createDb } from '../src/lib/server/shared/db';
import { createR2, r2ConfigFrom } from '../src/lib/server/shared/r2';
import { MEDIA_QUEUE, type MediaJob } from '../src/lib/server/shared/queue';
import { processMedia } from './process';

const log = (...a: unknown[]) => console.log(new Date().toISOString(), '[worker]', ...a);

async function main() {
	const url = process.env.DATABASE_URL;
	if (!url) throw new Error('DATABASE_URL is not set');
	const cfg = r2ConfigFrom(process.env);
	const ctx = { db: createDb(url, 3), s3: createR2(cfg), bucket: cfg.bucket, log };

	const boss = new PgBoss({ connectionString: url, max: 3 });
	boss.on('error', (e) => console.error('[pg-boss]', e));
	await boss.start();
	await boss.createQueue(MEDIA_QUEUE);

	// One job at a time: the VPS has 2 cores and ffmpeg uses both.
	await boss.work<MediaJob>(MEDIA_QUEUE, { batchSize: 1, pollingIntervalSeconds: 2 }, async ([job]) => {
		log(`job ${job.id} media ${job.data.mediaId}`);
		await processMedia(ctx, job.data.mediaId);
	});
	log('waiting for jobs');

	const stop = async () => {
		log('stopping');
		await boss.stop({ graceful: true, timeout: 30_000 });
		process.exit(0);
	};
	process.on('SIGTERM', stop);
	process.on('SIGINT', stop);
}

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
