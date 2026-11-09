import { error } from '@sveltejs/kit';
import { DeleteObjectsCommand } from '@aws-sdk/client-s3';
import { and, eq } from 'drizzle-orm';
import { checkins, db, media, users } from './db';
import { mediaUrl, r2 } from './r2';
import { listComments } from './comments';
import { likersOf } from './likes';
import { deleteObject } from './images';
import { clip, isLat, isLng } from './validate';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

async function mediaRow(id: string) {
	if (!UUID.test(id)) error(404, 'Não encontrado');
	const [row] = await db()
		.select({ m: media, name: users.name, color: users.color, avatarKey: users.avatarKey })
		.from(media)
		.innerJoin(users, eq(users.id, media.userId))
		.where(eq(media.id, id));
	if (!row || row.m.status === 'uploading') error(404, 'Não encontrado');
	return row;
}

/** One photo/video with its URLs, comments and likes (web /m/:id and GET /api/media/:id). */
export async function mediaDetail(id: string) {
	const { m, name, color, avatarKey } = await mediaRow(id);
	const [display, medium, video, poster, original, comments, photo, likers] = await Promise.all([
		mediaUrl(m.displayKey),
		mediaUrl(m.mediumKey),
		mediaUrl(m.videoKey),
		mediaUrl(m.posterKey),
		mediaUrl(m.originalKey, m.originalName),
		listComments({ mediaId: m.id }),
		mediaUrl(avatarKey),
		likersOf({ mediaId: m.id })
	]);
	return {
		item: {
			id: m.id,
			userId: m.userId,
			name,
			color,
			photo,
			kind: m.kind,
			status: m.status,
			error: m.error,
			at: (m.takenAt ?? m.createdAt).toISOString(),
			takenAtSource: m.takenAtSource,
			lat: m.lat,
			lng: m.lng,
			locationSource: m.locationSource,
			width: m.width,
			height: m.height,
			durationS: m.durationS,
			sizeBytes: m.sizeBytes,
			originalName: m.originalName,
			caption: m.caption,
			display,
			medium,
			video,
			poster,
			original
		},
		comments,
		likers
	};
}

async function ownedMedia(id: string, userId: string) {
	const { m } = await mediaRow(id);
	if (m.userId !== userId) error(403, 'Só quem enviou pode mudar isso.');
	return m;
}

/** Owner edits: caption and/or a manually placed location. */
export async function updateMedia(id: string, userId: string, patch: { caption?: unknown; lat?: unknown; lng?: unknown }) {
	const m = await ownedMedia(id, userId);
	const set: Partial<typeof media.$inferInsert> = {};
	if (patch.caption !== undefined) set.caption = clip(patch.caption, 2000);
	if (patch.lat !== undefined || patch.lng !== undefined) {
		const lat = Number(patch.lat), lng = Number(patch.lng);
		if (!isLat(lat) || !isLng(lng)) error(400, 'Local inválido.');
		Object.assign(set, { lat, lng, locationSource: 'manual' as const });
	}
	if (Object.keys(set).length) await db().update(media).set(set).where(eq(media.id, m.id));
}

export type Actor = { id: string; isAdmin: boolean };

/** Owner (or admin) delete: the row (comments and likes cascade) and every file in R2. */
export async function deleteMedia(id: string, user: Actor) {
	const { m } = await mediaRow(id);
	if (m.userId !== user.id && !user.isAdmin) error(403, 'Só quem enviou pode apagar.');
	const keys = [m.originalKey, m.displayKey, m.mediumKey, m.thumbKey, m.posterKey, m.videoKey].filter(Boolean) as string[];
	const { s3, bucket } = r2();
	await s3.send(new DeleteObjectsCommand({ Bucket: bucket, Delete: { Objects: keys.map((Key) => ({ Key })) } }));
	await db().delete(media).where(eq(media.id, m.id));
}

async function checkinRow(id: string) {
	if (!UUID.test(id)) error(404, 'Não encontrado');
	const [row] = await db()
		.select({ c: checkins, name: users.name, color: users.color, avatarKey: users.avatarKey })
		.from(checkins)
		.innerJoin(users, eq(users.id, checkins.userId))
		.where(eq(checkins.id, id));
	if (!row) error(404, 'Não encontrado');
	return row;
}

export async function checkinDetail(id: string) {
	const { c, name, color, avatarKey } = await checkinRow(id);
	const [photo, snapshot, comments, likers] = await Promise.all([
		mediaUrl(avatarKey),
		mediaUrl(c.snapshotKey),
		listComments({ checkinId: c.id }),
		likersOf({ checkinId: c.id })
	]);
	return {
		item: { id: c.id, userId: c.userId, name, color, photo, snapshot, lat: c.lat, lng: c.lng, note: c.note, at: c.createdAt.toISOString() },
		comments,
		likers
	};
}

export async function updateCheckinNote(id: string, userId: string, note: unknown) {
	const { c } = await checkinRow(id);
	if (c.userId !== userId) error(403, 'Só quem fez o check-in pode mudar isso.');
	await db().update(checkins).set({ note: clip(note, 2000) }).where(eq(checkins.id, c.id));
}

/** Owner (or admin); comments, likes and the map picture go with it. Returns false if it wasn't theirs. */
export async function deleteCheckin(id: string, user: Actor) {
	if (!UUID.test(id)) return false;
	const [c] = await db()
		.delete(checkins)
		.where(user.isAdmin ? eq(checkins.id, id) : and(eq(checkins.id, id), eq(checkins.userId, user.id)))
		.returning({ snapshotKey: checkins.snapshotKey });
	if (!c) return false;
	await deleteObject(c.snapshotKey);
	return true;
}

/** Throws 404 when the target doesn't exist (used before adding comments). */
export async function assertTarget(target: { mediaId: string } | { checkinId: string }) {
	if ('mediaId' in target) await mediaRow(target.mediaId);
	else await checkinRow(target.checkinId);
}
