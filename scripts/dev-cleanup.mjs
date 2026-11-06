// Removes the local dev test user, its rows (cascade) and its R2 files.  node --env-file=.env scripts/dev-cleanup.mjs
import postgres from 'postgres';
import { S3Client, DeleteObjectsCommand } from '@aws-sdk/client-s3';
const e = process.env;
const EMAIL = 'claude-local@example.test';
const sql = postgres(e.DATABASE_URL, { max: 1, onnotice: () => {} });
const s3 = new S3Client({ region: 'auto', endpoint: `https://${e.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`, credentials: { accessKeyId: e.R2_ACCESS_KEY_ID, secretAccessKey: e.R2_SECRET_ACCESS_KEY } });
const rows = await sql`select m.original_key, m.display_key, m.thumb_key, m.poster_key, m.video_key from media m join users u on u.id = m.user_id where u.email = ${EMAIL}`;
const keys = rows.flatMap((r) => Object.values(r)).filter(Boolean);
if (keys.length) {
	const r = await s3.send(new DeleteObjectsCommand({ Bucket: e.R2_BUCKET, Delete: { Objects: keys.map((Key) => ({ Key })) } }));
	console.log('R2 objects deleted:', r.Deleted?.length ?? 0, 'errors:', r.Errors?.length ?? 0);
}
const d = await sql`delete from users where email = ${EMAIL} returning id`;
console.log('test user removed:', d.length);
const [c] = await sql`select (select count(*) from users)::int users, (select count(*) from media)::int media, (select count(*) from checkins)::int checkins`;
console.log('remaining:', JSON.stringify(c));
await sql.end();
