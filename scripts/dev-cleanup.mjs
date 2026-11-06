// Removes local dev test users (claude-local*@example.test), their rows (cascade) and their R2 files.  node --env-file=.env scripts/dev-cleanup.mjs
import postgres from 'postgres';
import { S3Client, DeleteObjectsCommand } from '@aws-sdk/client-s3';
const e = process.env;
const PATTERN = 'claude-local%@example.test';
const sql = postgres(e.DATABASE_URL, { max: 1, onnotice: () => {} });
const s3 = new S3Client({ region: 'auto', endpoint: `https://${e.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`, credentials: { accessKeyId: e.R2_ACCESS_KEY_ID, secretAccessKey: e.R2_SECRET_ACCESS_KEY } });
const rows = await sql`select m.original_key, m.display_key, m.medium_key, m.thumb_key, m.poster_key, m.video_key from media m join users u on u.id = m.user_id where u.email like ${PATTERN}`;
const avatars = await sql`select avatar_key from users where email like ${PATTERN} and avatar_key is not null`;
const keys = [...rows.flatMap((r) => Object.values(r)), ...avatars.map((a) => a.avatar_key)].filter(Boolean);
if (keys.length) {
	const r = await s3.send(new DeleteObjectsCommand({ Bucket: e.R2_BUCKET, Delete: { Objects: keys.map((Key) => ({ Key })) } }));
	console.log('R2 objects deleted:', r.Deleted?.length ?? 0, 'errors:', r.Errors?.length ?? 0);
}
const d = await sql`delete from users where email like ${PATTERN} returning id`;
console.log('test users removed:', d.length);
const [c] = await sql`select (select count(*) from users)::int users, (select count(*) from media)::int media, (select count(*) from checkins)::int checkins`;
console.log('remaining:', JSON.stringify(c));
await sql.end();
