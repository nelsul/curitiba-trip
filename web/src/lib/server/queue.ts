import { env } from '$env/dynamic/private';
import PgBoss from 'pg-boss';
import { MEDIA_QUEUE, type MediaJob } from './shared/queue';

let boss: Promise<PgBoss> | undefined;

function getBoss() {
	boss ??= (async () => {
		// The worker owns maintenance; the web app only sends jobs.
		const b = new PgBoss({ connectionString: env.DATABASE_URL, supervise: false, schedule: false, max: 2 });
		b.on('error', (e) => console.error('[pg-boss]', e));
		await b.start();
		await b.createQueue(MEDIA_QUEUE);
		return b;
	})();
	return boss;
}

export async function enqueueMedia(mediaId: string) {
	const b = await getBoss();
	await b.send(MEDIA_QUEUE, { mediaId } satisfies MediaJob, {
		retryLimit: 3,
		retryDelay: 60,
		retryBackoff: true,
		expireInSeconds: 2 * 3600
	});
}
