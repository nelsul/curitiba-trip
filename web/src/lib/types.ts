export type Person = { id: string; name: string; color: string; photo: string | null };

export type FeedMedia = {
	type: 'media';
	id: string;
	userId: string;
	at: string;
	day: string;
	kind: 'photo' | 'video';
	/** 'preview': only a low-res picture so far; the original arrives when the sender's phone is on Wi-Fi */
	status: 'preview' | 'processing' | 'ready' | 'failed';
	thumb: string | null;
	/** big feed image: medium (1080px) → display → video poster */
	image: string | null;
	video: string | null;
	width: number | null;
	height: number | null;
	likers: string[];
	lat: number | null;
	lng: number | null;
	caption: string;
	comments: number;
	durationS: number | null;
};

export type FeedCheckin = {
	type: 'checkin';
	id: string;
	userId: string;
	at: string;
	day: string;
	lat: number;
	lng: number;
	note: string;
	/** map picture made at check-in time (null until generated) */
	snapshot: string | null;
	comments: number;
	likers: string[];
};

export type FeedItem = FeedMedia | FeedCheckin;

export type Ping = { userId: string; lat: number; lng: number; at: string };
