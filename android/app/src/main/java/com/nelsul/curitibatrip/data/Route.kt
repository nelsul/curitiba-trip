package com.nelsul.curitibatrip.data

/** A page pushed on top of a tab (photo/video, check-in, the Retrospectiva, a place). */
sealed interface Route {
	data class Media(val id: String) : Route
	data class Checkin(val id: String) : Route
	data object Retro : Route
	data class Place(val id: String) : Route
}
