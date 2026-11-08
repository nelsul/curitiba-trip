package com.nelsul.curitibatrip.data

import kotlinx.serialization.Serializable

// Types mirror web/API.md (and the iOS Models.swift). Dates arrive as ISO-8601 strings; URLs as strings.

@Serializable
data class Person(val id: String, val name: String, val color: String, val photo: String? = null)

@Serializable
data class Me(val id: String, val name: String, val color: String, val photo: String? = null, val isAdmin: Boolean = false, val minAppVersion: String? = null)

@Serializable data class CodeResponse(val maskedEmail: String)
@Serializable data class VerifyResponse(val token: String, val user: Me, val minAppVersion: String? = null)

@Serializable
data class FeedMedia(
	val id: String,
	val userId: String,
	val at: String,
	val day: String,
	val kind: String, // "photo" | "video"
	val status: String, // "processing" | "ready" | "failed"
	val thumb: String? = null,
	val image: String? = null,
	val video: String? = null,
	val width: Int? = null,
	val height: Int? = null,
	val likers: List<String> = emptyList(),
	val lat: Double? = null,
	val lng: Double? = null,
	val caption: String = "",
	val comments: Int = 0,
	val durationS: Double? = null,
) { val isVideo get() = kind == "video" }

@Serializable
data class FeedCheckin(
	val id: String,
	val userId: String,
	val at: String,
	val day: String,
	val lat: Double,
	val lng: Double,
	val note: String = "",
	val snapshot: String? = null,
	val comments: Int = 0,
	val likers: List<String> = emptyList(),
)

/** A feed post: a carousel of photos/videos (`items`), or a check-in (`item`), grouped by the server like the web. */
@Serializable
data class Post(
	val type: String,
	val key: String,
	val userId: String,
	val day: String,
	val at: String,
	val items: List<FeedMedia> = emptyList(),
	val item: FeedCheckin? = null,
)

@Serializable data class FeedPage(val posts: List<Post>, val nextCursor: String? = null, val days: List<String>? = null)
@Serializable data class LikeBody(val mediaId: String? = null, val checkinId: String? = null, val liked: Boolean)
@Serializable data class LikeResponse(val likers: List<String>)
@Serializable data class Ok(val ok: Boolean? = null)

// ── Details and comments ──

@Serializable
data class Comment(val id: String, val body: String, val at: String, val userId: String, val name: String, val color: String, val photo: String? = null)

@Serializable
data class MediaItem(
	val id: String,
	val userId: String,
	val kind: String,
	val status: String,
	val at: String,
	val takenAtSource: String? = null,
	val lat: Double? = null,
	val lng: Double? = null,
	val locationSource: String? = null,
	val width: Int? = null,
	val height: Int? = null,
	val durationS: Double? = null,
	val sizeBytes: Long = 0,
	val originalName: String = "",
	val caption: String = "",
	val display: String? = null,
	val medium: String? = null,
	val video: String? = null,
	val poster: String? = null,
	val original: String? = null,
	val mimeType: String? = null,
) { val isVideo get() = kind == "video" }

@Serializable data class MediaDetail(val item: MediaItem, val comments: List<Comment> = emptyList(), val likers: List<String> = emptyList())

@Serializable
data class CheckinItem(val id: String, val userId: String, val snapshot: String? = null, val lat: Double, val lng: Double, val note: String = "", val at: String)

@Serializable data class CheckinDetail(val item: CheckinItem, val comments: List<Comment> = emptyList(), val likers: List<String> = emptyList())

// ── Itinerary ──

@Serializable
data class Itinerary(val transport: Map<String, Transport> = emptyMap(), val days: List<Day> = emptyList()) {
	@Serializable data class Transport(val label: String)
	@Serializable data class Place(val id: String, val name: String, val lat: Double, val lng: Double, val hours: String = "", val mapsUrl: String, val uberUrl: String)
	@Serializable data class Stop(val time: String, val transport: String, val note: String = "", val title: String, val place: Place? = null)
	@Serializable data class Day(val date: String, val title: String, val who: String = "", val lead: String = "", val wedding: Boolean = false, val routeUrl: String? = null, val stops: List<Stop> = emptyList())
}

// ── Devices ──

@Serializable data class Device(val id: String, val deviceName: String? = null, val lastUsedAt: String? = null, val createdAt: String? = null, val current: Boolean = false)

// ── Map (GET /api/map) ──

/** A located post (`type` "media") or check-in ("checkin"). */
@Serializable
data class MapItem(
	val type: String,
	val id: String,
	val userId: String,
	val at: String,
	val day: String,
	val lat: Double? = null,
	val lng: Double? = null,
	val kind: String? = null,
	val thumb: String? = null,
) { val isVideo get() = kind == "video" }

@Serializable data class MapPing(val userId: String, val lat: Double, val lng: Double, val at: String, val day: String)
@Serializable data class LatestLocation(val userId: String, val name: String, val color: String, val photo: String? = null, val lat: Double, val lng: Double, val at: String)
@Serializable data class MapData(val items: List<MapItem> = emptyList(), val pings: List<MapPing> = emptyList(), val latest: List<LatestLocation> = emptyList())
@Serializable data class Created(val id: String)
@Serializable data class PositionBody(val lat: Double, val lng: Double, val accuracy: Double? = null)
@Serializable data class CheckinBody(val lat: Double, val lng: Double, val accuracy: Double, val note: String)
@Serializable data class LatLngBody(val lat: Double, val lng: Double)

/** GET /api/places */
@Serializable data class PlaceResult(val name: String, val detail: String = "", val lat: Double, val lng: Double)
