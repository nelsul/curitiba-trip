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

@Serializable data class FeedPage(val posts: List<Post>, val nextCursor: String? = null)
@Serializable data class LikeBody(val mediaId: String? = null, val checkinId: String? = null, val liked: Boolean)
@Serializable data class LikeResponse(val likers: List<String>)
@Serializable data class Ok(val ok: Boolean? = null)
