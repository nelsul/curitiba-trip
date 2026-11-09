package com.nelsul.curitibatrip.feature.roteiro

import android.net.Uri
import androidx.compose.ui.graphics.Color
import com.nelsul.curitibatrip.ui.theme.Palette
import kotlinx.serialization.Serializable

// GET /api/roteiro (web/API.md): the shared places and the days, editable by everyone.

@Serializable data class RoteiroData(val places: List<RoteiroPlace> = emptyList(), val days: List<RoteiroDay> = emptyList())

@Serializable data class PlacePhoto(val id: String, val url: String)

@Serializable
data class RoteiroPlace(
	val id: String,
	val name: String,
	val category: String = "passeio",
	val lat: Double,
	val lng: Double,
	val address: String = "",
	val hours: String = "",
	val price: String = "",
	val priceLevel: Int? = null,
	val description: String = "",
	val link: String = "",
	val googlePlaceId: String? = null,
	val photos: List<PlacePhoto> = emptyList(),
) {
	val categoryInfo get() = RoteiroCategory.of(category)

	/** Opens the Uber app (or m.uber.com) with the place as the destination. */
	val uberUrl: String
		get() = Uri.parse("https://m.uber.com/ul/").buildUpon()
			.appendQueryParameter("action", "setPickup").appendQueryParameter("pickup", "my_location")
			.appendQueryParameter("dropoff[latitude]", lat.toString()).appendQueryParameter("dropoff[longitude]", lng.toString())
			.appendQueryParameter("dropoff[nickname]", name).build().toString()

	/** Its Google Maps page (the Google listing when known, otherwise the coordinates). */
	val mapsUrl: String
		get() = Uri.parse("https://www.google.com/maps/search/").buildUpon().appendQueryParameter("api", "1")
			.appendQueryParameter("query", if (googlePlaceId != null) name else "$lat,$lng")
			.apply { googlePlaceId?.let { appendQueryParameter("query_place_id", it) } }.build().toString()
}

@Serializable
data class RoteiroStop(
	val id: String,
	val time: String = "",
	val placeId: String? = null,
	val label: String = "",
	val transport: String = "pe",
	val note: String = "",
	val visitedAt: String? = null,
	val visitedBy: String? = null,
)

@Serializable
data class RoteiroDay(
	val date: String,
	val title: String = "",
	val who: String = "",
	val lead: String = "",
	val wedding: Boolean = false,
	val stops: List<RoteiroStop> = emptyList(),
)

enum class RoteiroCategory(val key: String, val label: String, val plural: String, val color: Color) {
	Comer("comer", "Comer", "Para comer", Palette.coral),
	Passeio("passeio", "Passear", "Para passear", Palette.leaf),
	Outro("outro", "Outro", "Outros", Palette.sea);

	companion object { fun of(k: String) = entries.firstOrNull { it.key == k } ?: Passeio }
}

enum class RoteiroTransport(val key: String, val label: String, val color: Color) {
	Onibus("onibus", "🚌 Ônibus", Palette.sky),
	Turismo("turismo", "🚍 Linha Turismo", Palette.leaf),
	Uber("uber", "🚗 Uber", Palette.plum),
	Pe("pe", "🚶 A pé", Palette.coral),
	Rodo("rodo", "🚌 Ônibus Graciosa", Palette.sky);

	companion object { fun of(k: String) = entries.firstOrNull { it.key == k } ?: Pe }
}

object Roteiro {
	/** "$$" for price levels 1–4, "Grátis" for 0. */
	fun priceSigns(level: Int?) = when (level) { null -> ""; 0 -> "Grátis"; else -> "$".repeat(level) }

	/** "9h35" / "14h" → minutes after midnight (null for free text like "Ida e volta"). */
	fun minutes(time: String): Int? {
		val m = Regex("""^(\d{1,2})h(\d{2})?$""").matchEntire(time.trim()) ?: return null
		return m.groupValues[1].toInt() * 60 + (m.groupValues[2].toIntOrNull() ?: 0)
	}

	/** minutes → "9h35" / "14h" (the format the apps read for reminders) */
	fun timeText(minutes: Int): String {
		val h = minutes / 60
		val m = minutes % 60
		return if (m == 0) "${h}h" else "%dh%02d".format(h, m)
	}

	/** Google Maps directions through the places, in order. */
	fun routeUrl(places: List<RoteiroPlace>): String? {
		if (places.size < 2) return null
		val ll = { p: RoteiroPlace -> "${p.lat},${p.lng}" }
		return Uri.parse("https://www.google.com/maps/dir/").buildUpon().appendQueryParameter("api", "1")
			.appendQueryParameter("origin", ll(places.first())).appendQueryParameter("destination", ll(places.last()))
			.appendQueryParameter("travelmode", "driving")
			.apply { if (places.size > 2) appendQueryParameter("waypoints", places.drop(1).dropLast(1).joinToString("|", transform = ll)) }
			.build().toString()
	}
}

// ── request bodies ──

@Serializable
data class PlaceBody(
	val name: String,
	val category: String,
	val lat: Double,
	val lng: Double,
	val address: String,
	val hours: String,
	val price: String,
	/** left out when null, which the server reads as "não sei" */
	val priceLevel: Int? = null,
	val description: String,
	val link: String,
)

@Serializable
data class DayBody(val title: String, val who: String, val lead: String, val wedding: Boolean, val stops: List<Stop>) {
	@Serializable
	data class Stop(val id: String? = null, val time: String, val placeId: String? = null, val label: String, val transport: String, val note: String)

	companion object {
		fun of(d: RoteiroDay, stops: List<Stop> = d.stops.map { Stop(it.id, it.time, it.placeId, it.label, it.transport, it.note) }) =
			DayBody(d.title, d.who, d.lead, d.wedding, stops)
	}
}

@Serializable data class VisitBody(val visited: Boolean)
@Serializable data class VisitResult(val visitedAt: String? = null, val visitedBy: String? = null)
@Serializable data class CreatedPlace(val id: String)

/** GET /api/roteiro/days/:date/route */
@Serializable
data class DayRoute(val legs: List<Leg> = emptyList()) {
	@Serializable data class Leg(val transport: String, val coordinates: List<List<Double>> = emptyList(), val routed: Boolean = false)
}
