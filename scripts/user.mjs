// Usage (inside the app container):
//   node scripts/user.mjs add "Nome" email@example.com [--admin] [--color "#3E6E9A"]
//   node scripts/user.mjs list
import postgres from 'postgres';

const PALETTE = ['#2F5A40', '#C4747E', '#3E6E9A', '#7A4A2E', '#8A5BB0', '#D08A2E', '#2E8A8A', '#B0465E', '#5B7A2E', '#4E5BA6'];
const sql = postgres(process.env.DATABASE_URL, { max: 1, onnotice: () => {} });
const [cmd, ...rest] = process.argv.slice(2);
try {
	if (cmd === 'add') {
		const flags = new Map();
		const pos = [];
		for (let i = 0; i < rest.length; i++) {
			if (rest[i] === '--admin') flags.set('admin', true);
			else if (rest[i] === '--color') flags.set('color', rest[++i]);
			else pos.push(rest[i]);
		}
		const [name, rawEmail] = pos;
		if (!name || !rawEmail) throw new Error('usage: add "Name" email [--admin] [--color #hex]');
		const email = rawEmail.trim().toLowerCase();
		const [{ n }] = await sql`select count(*)::int as n from users`;
		const color = flags.get('color') ?? PALETTE[n % PALETTE.length];
		await sql`insert into users (name, email, color, is_admin) values (${name}, ${email}, ${color}, ${!!flags.get('admin')})
			on conflict (email) do update set name = excluded.name, is_admin = excluded.is_admin or users.is_admin`;
		console.log(`ok: ${name}`);
	} else if (cmd === 'list') {
		for (const u of await sql`select name, email, color, is_admin from users order by created_at`)
			console.log(`${u.is_admin ? '*' : ' '} ${u.name.padEnd(12)} ${u.color} ${u.email}`);
	} else {
		console.log('commands: add, list');
	}
} finally {
	await sql.end();
}
