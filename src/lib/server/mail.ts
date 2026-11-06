import { env } from '$env/dynamic/private';
import nodemailer from 'nodemailer';

let transport: nodemailer.Transporter | undefined;

export async function sendLoginCode(to: string, name: string, code: string) {
	if (!env.SMTP_HOST || !env.SMTP_USERNAME || !env.SMTP_PASSWORD) {
		console.warn(`[mail] SMTP not configured. Code for ${to}: ${code}`);
		return;
	}
	const port = Number(env.SMTP_PORT || 465);
	transport ??= nodemailer.createTransport({
		host: env.SMTP_HOST,
		port,
		secure: port === 465,
		auth: { user: env.SMTP_USERNAME, pass: env.SMTP_PASSWORD }
	});
	const spaced = `${code.slice(0, 3)} ${code.slice(3)}`;
	await transport.sendMail({
		from: { name: 'Viagem a Curitiba', address: env.SMTP_FROM_EMAIL || env.SMTP_USERNAME },
		to,
		subject: `Seu código de acesso: ${spaced}`,
		text: `Oi, ${name}!\n\nSeu código para entrar no app da viagem é: ${spaced}\n\nEle vale por 10 minutos. Se você não pediu este código, pode ignorar este e-mail.`,
		html: `<div style="font-family:system-ui,sans-serif;font-size:16px;color:#1C2B22">
<p>Oi, ${escapeHtml(name)}!</p>
<p>Seu código para entrar no app da viagem é:</p>
<p style="font-size:32px;font-weight:700;letter-spacing:6px;color:#2F5A40;margin:16px 0">${spaced}</p>
<p style="color:#5D6B62">Ele vale por 10 minutos. Se você não pediu este código, pode ignorar este e-mail.</p>
</div>`
	});
}

function escapeHtml(s: string) {
	return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}
