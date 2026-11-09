package com.nelsul.curitibatrip.feature.roteiro

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.data.WeatherData
import com.nelsul.curitibatrip.data.WeatherDay
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import java.time.Instant
import java.time.ZonedDateTime

object Weather {
	fun icon(kind: String) = when (kind) { "sun" -> IconName.Sun; "partly" -> IconName.Partly; "cloud" -> IconName.Cloud; "fog" -> IconName.Fog; "storm" -> IconName.Storm; else -> IconName.Rain }
	fun label(kind: String) = when (kind) { "sun" -> "Sol"; "partly" -> "Sol entre nuvens"; "cloud" -> "Nublado"; "fog" -> "Neblina"; "storm" -> "Tempestade"; else -> "Chuva" }
	fun color(t: Int): Color = if (t >= 26) Palette.coral else if (t >= 20) Palette.sun else if (t >= 14) Palette.leaf else Palette.sky

	/** The trip's forecast (GET /api/weather), loaded at most every 15 minutes. */
	var days by mutableStateOf<Map<String, WeatherDay>>(emptyMap())
		private set
	private var loadedAt = Instant.EPOCH
	suspend fun load() {
		if (Instant.now().isBefore(loadedAt.plusSeconds(15 * 60))) return
		runCatching { Api.get<WeatherData>("/api/weather") }.getOrNull()?.let { w ->
			days = w.days.associateBy { it.date }
			loadedAt = Instant.now()
		}
	}
}

/** One day's forecast: the summary and an hour-by-hour strip from 6h (scrolled to now on today, else to 8h). */
@Composable
fun WeatherCard(day: WeatherDay, modifier: Modifier = Modifier) {
	val hours = day.hours.filter { (it.time.take(2).toIntOrNull() ?: 0) >= 6 }
	val scroll = rememberScrollState()
	val density = LocalDensity.current
	LaunchedEffect(day.date) {
		val now = ZonedDateTime.now(TripTime.zone)
		val target = if (day.date == now.toLocalDate().toString()) now.hour else 8
		val i = hours.indexOfFirst { (it.time.take(2).toIntOrNull() ?: 0) >= target }.coerceAtLeast(0)
		scroll.scrollTo(with(density) { (i * 50).dp.roundToPx() })
	}
	Column(
		modifier.fillMaxWidth().background(Palette.surface, RoundedCornerShape(18.dp)).border(2.5.dp, Palette.line, RoundedCornerShape(18.dp)).padding(12.dp),
		verticalArrangement = Arrangement.spacedBy(8.dp),
	) {
		Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
			Icon(Weather.icon(day.kind), Weather.color(day.max), size = 34.dp)
			Column {
				Text("${day.min}° a ${day.max}°", style = display(19), color = Palette.ink)
				Text(Weather.label(day.kind) + if (day.rain >= 20) " · ${day.rain}% de chuva" else "", style = body(13), color = Palette.muted)
			}
		}
		Row(Modifier.horizontalScroll(scroll), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
			hours.forEach { h ->
				Column(
					Modifier.widthIn(min = 46.dp).background(Palette.surface2, RoundedCornerShape(12.dp)).padding(vertical = 6.dp)
						.clearAndSetSemantics { contentDescription = "${h.time}: ${h.temp} graus, ${Weather.label(h.kind)}${if (h.rain >= 20) ", ${h.rain}% de chuva" else ""}" },
					horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp),
				) {
					Text(h.time.replace(":00", "h"), style = body(12, FontWeight.ExtraBold), color = Palette.muted)
					Icon(Weather.icon(h.kind), Weather.color(h.temp), size = 20.dp)
					Text("${h.temp}°", style = body(15, FontWeight.ExtraBold), color = Palette.ink)
					Text("${h.rain}%", style = body(11, FontWeight.ExtraBold), color = Palette.sky, modifier = Modifier.alpha(if (h.rain >= 20) 1f else 0f))
				}
			}
		}
	}
}
