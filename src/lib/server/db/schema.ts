import {
	pgTable,
	text,
	uuid,
	boolean,
	timestamp,
	integer,
	doublePrecision,
	real,
	bigint,
	bigserial,
	index
} from 'drizzle-orm/pg-core';

const createdAt = () => timestamp('created_at', { withTimezone: true }).notNull().defaultNow();

export const users = pgTable('users', {
	id: uuid('id').primaryKey().defaultRandom(),
	name: text('name').notNull(),
	email: text('email').notNull().unique(), // always lowercase
	color: text('color').notNull().default('#2F5A40'),
	avatarKey: text('avatar_key'), // R2 key of the profile photo (avatars/<userId>/<random>.webp)
	isAdmin: boolean('is_admin').notNull().default(false),
	createdAt: createdAt()
});

export const loginCodes = pgTable(
	'login_codes',
	{
		id: bigserial('id', { mode: 'number' }).primaryKey(),
		email: text('email').notNull(),
		codeHash: text('code_hash').notNull(),
		attempts: integer('attempts').notNull().default(0),
		expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
		usedAt: timestamp('used_at', { withTimezone: true }),
		createdAt: createdAt()
	},
	(t) => [index('login_codes_email_idx').on(t.email, t.createdAt)]
);

export const sessions = pgTable('sessions', {
	id: text('id').primaryKey(), // sha256 of the cookie token
	userId: uuid('user_id')
		.notNull()
		.references(() => users.id, { onDelete: 'cascade' }),
	expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
	createdAt: createdAt()
});

export type MediaKind = 'photo' | 'video';
export type MediaStatus = 'uploading' | 'processing' | 'ready' | 'failed';
export type LocationSource = 'exif' | 'device' | 'manual';
export type TimeSource = 'exif' | 'file' | 'upload';

export const media = pgTable(
	'media',
	{
		id: uuid('id').primaryKey().defaultRandom(),
		userId: uuid('user_id')
			.notNull()
			.references(() => users.id, { onDelete: 'cascade' }),
		kind: text('kind').$type<MediaKind>().notNull(),
		status: text('status').$type<MediaStatus>().notNull().default('uploading'),
		uploadId: text('upload_id'),
		originalKey: text('original_key').notNull(),
		originalName: text('original_name').notNull(),
		mimeType: text('mime_type').notNull(),
		sizeBytes: bigint('size_bytes', { mode: 'number' }).notNull(),
		takenAt: timestamp('taken_at', { withTimezone: true }),
		takenAtSource: text('taken_at_source').$type<TimeSource>(),
		lat: doublePrecision('lat'),
		lng: doublePrecision('lng'),
		locationSource: text('location_source').$type<LocationSource>(),
		width: integer('width'),
		height: integer('height'),
		durationS: real('duration_s'),
		thumbKey: text('thumb_key'),
		displayKey: text('display_key'),
		posterKey: text('poster_key'),
		videoKey: text('video_key'),
		caption: text('caption').notNull().default(''),
		error: text('error'),
		createdAt: createdAt(),
		processedAt: timestamp('processed_at', { withTimezone: true })
	},
	(t) => [index('media_taken_idx').on(t.takenAt), index('media_user_idx').on(t.userId)]
);

export const checkins = pgTable(
	'checkins',
	{
		id: uuid('id').primaryKey().defaultRandom(),
		userId: uuid('user_id')
			.notNull()
			.references(() => users.id, { onDelete: 'cascade' }),
		lat: doublePrecision('lat').notNull(),
		lng: doublePrecision('lng').notNull(),
		accuracyM: real('accuracy_m'),
		note: text('note').notNull().default(''),
		createdAt: createdAt()
	},
	(t) => [index('checkins_created_idx').on(t.createdAt)]
);

/** Positions sent while someone has the app open with sharing on (thinned on insert). */
export const locationPings = pgTable(
	'location_pings',
	{
		id: bigserial('id', { mode: 'number' }).primaryKey(),
		userId: uuid('user_id')
			.notNull()
			.references(() => users.id, { onDelete: 'cascade' }),
		lat: doublePrecision('lat').notNull(),
		lng: doublePrecision('lng').notNull(),
		accuracyM: real('accuracy_m'),
		createdAt: createdAt()
	},
	(t) => [index('pings_user_time_idx').on(t.userId, t.createdAt)]
);

export const comments = pgTable(
	'comments',
	{
		id: uuid('id').primaryKey().defaultRandom(),
		userId: uuid('user_id')
			.notNull()
			.references(() => users.id, { onDelete: 'cascade' }),
		mediaId: uuid('media_id').references(() => media.id, { onDelete: 'cascade' }),
		checkinId: uuid('checkin_id').references(() => checkins.id, { onDelete: 'cascade' }),
		body: text('body').notNull(),
		createdAt: createdAt()
	},
	(t) => [index('comments_media_idx').on(t.mediaId), index('comments_checkin_idx').on(t.checkinId)]
);

export type User = typeof users.$inferSelect;
export type Media = typeof media.$inferSelect;
export type Checkin = typeof checkins.$inferSelect;
