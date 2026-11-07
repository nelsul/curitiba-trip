package com.nelsul.curitibatrip.data

/** A page pushed on top of a tab (photo/video or check-in). */
sealed interface Route {
	data class Media(val id: String) : Route
	data class Checkin(val id: String) : Route
}
