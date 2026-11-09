import { sql } from 'drizzle-orm';
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
	index,
	uniqueIndex
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

export type SessionKind = 'cookie' | 'device';

export const sessions = pgTable(
	'sessions',
	{
		id: text('id').primaryKey(), // sha256 of the token (cookie or bearer); the token itself is never stored
		userId: uuid('user_id')
			.notNull()
			.references(() => users.id, { onDelete: 'cascade' }),
		kind: text('kind').$type<SessionKind>().notNull().default('cookie'), // 'device' = iOS app (Bearer token)
		deviceName: text('device_name'), // e.g. "iPhone de Nelson", shown in the devices list
		lastUsedAt: timestamp('last_used_at', { withTimezone: true }),
		expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
		createdAt: createdAt()
	},
	(t) => [index('sessions_user_idx').on(t.userId)]
);

export type MediaKind = 'photo' | 'video';
export type MediaStatus = 'uploading' | 'processing' | 'ready' | 'failed';
/** device-library = taken from the iPhone's photo library entry (PHAsset), sent by the iOS app */
export type LocationSource = 'exif' | 'device' | 'device-library' | 'manual';
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
		mediumKey: text('medium_key'), // ~1080px, used by the feed
		posterKey: text('poster_key'),
		videoKey: text('video_key'),
		caption: text('caption').notNull().default(''),
		/** the iPhone photo-library ID (iOS app): one post per photo per person, so retries never duplicate */
		clientAssetId: text('client_asset_id'),
		error: text('error'),
		createdAt: createdAt(),
		processedAt: timestamp('processed_at', { withTimezone: true })
	},
	(t) => [
		index('media_taken_idx').on(t.takenAt),
		index('media_user_idx').on(t.userId),
		uniqueIndex('media_user_asset_uq').on(t.userId, t.clientAssetId).where(sql`client_asset_id is not null`)
	]
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
		snapshotKey: text('snapshot_key'), // R2 key of the map picture made in the browser at check-in time
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

export const likes = pgTable(
	'likes',
	{
		id: bigserial('id', { mode: 'number' }).primaryKey(),
		userId: uuid('user_id')
			.notNull()
			.references(() => users.id, { onDelete: 'cascade' }),
		mediaId: uuid('media_id').references(() => media.id, { onDelete: 'cascade' }),
		checkinId: uuid('checkin_id').references(() => checkins.id, { onDelete: 'cascade' }),
		createdAt: createdAt()
	},
	(t) => [
		// one like per person per item (nulls are distinct, so media and check-in likes don't collide)
		uniqueIndex('likes_user_media_uq').on(t.userId, t.mediaId),
		uniqueIndex('likes_user_checkin_uq').on(t.userId, t.checkinId)
	]
);

export type User = typeof users.$inferSelect;
export type Media = typeof media.$inferSelect;
export type Checkin = typeof checkins.$inferSelect;

// ── Roteiro: shared places and the day-by-day itinerary (the same for everyone, anyone can edit) ──

export type PlaceCategory = 'comer' | 'passeio' | 'outro';
export type Transport = 'onibus' | 'turismo' | 'uber' | 'pe' | 'rodo';

export const places = pgTable('places', {
	/** short slug for the original itinerary places (apps use it for arrival areas), random for new ones */
	id: text('id').primaryKey(),
	name: text('name').notNull(),
	category: text('category').$type<PlaceCategory>().notNull().default('passeio'),
	lat: doublePrecision('lat').notNull(),
	lng: doublePrecision('lng').notNull(),
	address: text('address').notNull().default(''),
	/** opening hours as people write them ("ter–sáb 8h–18h; fecha seg") */
	hours: text('hours').notNull().default(''),
	/** "R$ 60–90 por pessoa", "grátis"… */
	price: text('price').notNull().default(''),
	/** 0 = free, 1–4 = $ to $$$$; null = unknown */
	priceLevel: integer('price_level'),
	description: text('description').notNull().default(''),
	link: text('link').notNull().default(''),
	googlePlaceId: text('google_place_id'),
	createdBy: uuid('created_by').references(() => users.id, { onDelete: 'set null' }),
	createdAt: createdAt(),
	updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow()
});

export const placePhotos = pgTable(
	'place_photos',
	{
		id: uuid('id').primaryKey().defaultRandom(),
		placeId: text('place_id')
			.notNull()
			.references(() => places.id, { onDelete: 'cascade' }),
		key: text('key').notNull(),
		userId: uuid('user_id').references(() => users.id, { onDelete: 'set null' }),
		createdAt: createdAt()
	},
	(t) => [index('place_photos_place_idx').on(t.placeId)]
);

export const itineraryDays = pgTable('itinerary_days', {
	/** YYYY-MM-DD (Curitiba) */
	date: text('date').primaryKey(),
	title: text('title').notNull().default(''),
	who: text('who').notNull().default(''),
	lead: text('lead').notNull().default(''),
	wedding: boolean('wedding').notNull().default(false),
	updatedBy: uuid('updated_by').references(() => users.id, { onDelete: 'set null' }),
	updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow()
});

export const itineraryStops = pgTable(
	'itinerary_stops',
	{
		id: uuid('id').primaryKey().defaultRandom(),
		day: text('day')
			.notNull()
			.references(() => itineraryDays.date, { onDelete: 'cascade', onUpdate: 'cascade' }),
		position: integer('position').notNull(),
		/** "9h35", "14h", or free text ("Ida e volta"); the apps remind 30 min before times like "9h35" */
		time: text('time').notNull().default(''),
		placeId: text('place_id').references(() => places.id, { onDelete: 'set null' }),
		/** title when there's no place ("Salão do casamento") */
		label: text('label').notNull().default(''),
		transport: text('transport').$type<Transport>().notNull().default('pe'),
		note: text('note').notNull().default(''),
		/** someone in the group ticked "Fomos!" (one tick counts for everyone) */
		visitedAt: timestamp('visited_at', { withTimezone: true }),
		visitedBy: uuid('visited_by').references(() => users.id, { onDelete: 'set null' })
	},
	(t) => [index('itinerary_stops_day_idx').on(t.day, t.position)]
);

export type Place = typeof places.$inferSelect;

// ── Hospedagem: where people sleep (hotel / Airbnb), set up by admins. Each person's Roteiro day starts and
// ends at their own stay. ──

export type StayKind = 'hotel' | 'airbnb' | 'casa';

export const stays = pgTable('stays', {
	id: uuid('id').primaryKey().defaultRandom(),
	name: text('name').notNull(),
	kind: text('kind').$type<StayKind>().notNull().default('hotel'),
	lat: doublePrecision('lat').notNull(),
	lng: doublePrecision('lng').notNull(),
	address: text('address').notNull().default(''),
	link: text('link').notNull().default(''),
	/** YYYY-MM-DD: the first night there (null = since the start of the trip) */
	checkIn: text('check_in'),
	/** YYYY-MM-DD: the day you leave (null = until the end of the trip) */
	checkOut: text('check_out'),
	note: text('note').notNull().default(''),
	createdAt: createdAt()
});

export const stayGuests = pgTable(
	'stay_guests',
	{
		stayId: uuid('stay_id')
			.notNull()
			.references(() => stays.id, { onDelete: 'cascade' }),
		userId: uuid('user_id')
			.notNull()
			.references(() => users.id, { onDelete: 'cascade' })
	},
	(t) => [uniqueIndex('stay_guests_pk').on(t.stayId, t.userId), index('stay_guests_user_idx').on(t.userId)]
);

export type Stay = typeof stays.$inferSelect;
