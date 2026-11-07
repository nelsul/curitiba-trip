package com.nelsul.curitibatrip.feature.roteiro

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.Itinerary
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.feature.feed.EmptyState
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.Chip
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TitleRow
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.Radius
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import com.nelsul.curitibatrip.ui.theme.popIn
import kotlinx.coroutines.launch
import java.time.Instant

/** Roteiro (web /roteiro): day chips + a boarding-pass ticket per day, with Uber and Google Maps buttons. */
@Composable
fun RoteiroScreen(contentPadding: PaddingValues) {
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	var itinerary by remember { mutableStateOf<Itinerary?>(null) }
	var selected by remember { mutableStateOf<String?>(null) }
	var error by remember { mutableStateOf<String?>(null) }
	val open: (String) -> Unit = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(it))) }

	suspend fun load() {
		try {
			val it: Itinerary = Api.get("/api/itinerary")
			itinerary = it
			val today = TripTime.dayKey(Instant.now().toString())
			if (selected == null) selected = it.days.firstOrNull { d -> d.date == today }?.date ?: it.days.firstOrNull()?.date
			error = null
		} catch (e: Exception) { error = e.message }
	}
	LaunchedEffect(Unit) { load() }
	val days = itinerary?.days.orEmpty()
	val day = days.firstOrNull { it.date == selected } ?: days.firstOrNull()

	Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
		Column(Modifier.widthIn(max = 640.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
			TitleRow(IconName.Ticket, "Roteiro")
			error?.let { EmptyState(it, retry = { scope.launch { load() } }) }
			Row(Modifier.horizontalScroll(rememberScrollState()).padding(vertical = 6.dp, horizontal = 2.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
				days.forEach { d ->
					Chip(d.date == day?.date, { selected = d.date }, dashed = true, tint = if (d.wedding) Palette.berry else null) {
						Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(vertical = 4.dp)) {
							Text(d.date.takeLast(2), style = display(17))
							Text(TripTime.shortWeekday(d.date), style = body(11, FontWeight.ExtraBold))
						}
					}
				}
			}
			if (day != null) {
				AnimatedContent(day, transitionSpec = { (slideInHorizontally { it / 3 } + fadeIn()) togetherWith fadeOut() }, label = "day") { d ->
					Ticket(d, days.indexOf(d) + 1, days.size, itinerary!!, open)
				}
			}
		}
	}
}

@Composable
private fun Ticket(d: Itinerary.Day, index: Int, total: Int, it: Itinerary, open: (String) -> Unit) {
	val shape = RoundedCornerShape(Radius.card)
	Column(
		Modifier
			.drawBehind { drawRoundRect(Palette.shadow, topLeft = Offset(0f, 5.dp.toPx()), size = size, cornerRadius = CornerRadius(Radius.card.toPx())) }
			.clip(shape)
			.background(Palette.surface)
			.border(2.5.dp, if (d.wedding) Palette.berry else Palette.line, shape),
	) {
		Row(Modifier.fillMaxWidth().background(if (d.wedding) Palette.berry else Palette.seaDark).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
			Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
				Text(if (d.wedding) "DIA ESPECIAL" else "DIA $index DE $total", style = body(12, FontWeight.ExtraBold).copy(letterSpacing = 1.2.sp), color = Color.White.copy(alpha = 0.9f))
				Text(d.title, style = display(24), color = Color.White)
			}
			Column(
				Modifier
					.rotate(10f)
					.size(64.dp)
					.drawBehind {
						drawCircle(Color.White.copy(alpha = 0.8f), radius = size.minDimension / 2 - 1.5.dp.toPx(),
							style = Stroke(3.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx()))))
					},
				horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
			) {
				Text(d.date.takeLast(2), style = display(26), color = Color.White)
				Text("NOV", style = body(11, FontWeight.ExtraBold), color = Color.White, modifier = Modifier.offset(y = (-4).dp))
			}
		}
		Box(Modifier.fillMaxWidth().padding(horizontal = 14.dp).height(3.dp).drawBehind {
			drawLine(Palette.line, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), 3.dp.toPx(),
				pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 5.dp.toPx())))
		})
		Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
			Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
				Icon(IconName.People, Palette.muted, size = 16.dp)
				Text(d.who, style = body(14, FontWeight.Bold), color = Palette.muted)
			}
			Text(d.lead, style = body(17), color = Palette.ink)
			d.stops.forEachIndexed { i, s -> Stop(s, it, open, Modifier.popIn(100L + i * 70L)) }
			if (d.routeUrl != null && !d.wedding) {
				ChunkyButton("Rota do dia no Google Maps", { open(d.routeUrl) }, variant = ButtonVariant.Sea, fullWidth = true, icon = IconName.Map)
			}
		}
	}
}

@Composable
private fun Stop(s: Itinerary.Stop, it: Itinerary, open: (String) -> Unit, modifier: Modifier) {
	val tc = transportColor(s.transport)
	Row(modifier, horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
		Text(
			s.time, style = display(13), color = Palette.onSun, maxLines = 2,
			textAlign = androidx.compose.ui.text.style.TextAlign.Center,
			modifier = Modifier
				.padding(top = 10.dp)
				.width(58.dp)
				.drawBehind {
					val r = CornerRadius(10.dp.toPx())
					drawRoundRect(Palette.sunDark, topLeft = Offset(0f, 2.dp.toPx()), size = size, cornerRadius = r)
					drawRoundRect(Palette.sun, cornerRadius = r)
				}
				.padding(vertical = 3.dp),
		)
		Column(Modifier.weight(1f).card(padding = 12.dp, radius = 18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
			Text(s.title, style = body(17, FontWeight.ExtraBold), color = Palette.ink)
			Text(it.transport[s.transport]?.label ?: s.transport, style = body(13, FontWeight.ExtraBold), color = tc,
				modifier = Modifier.border(2.dp, tc, CircleShape).padding(horizontal = 10.dp, vertical = 1.dp))
			Text(s.note, style = body(15), color = Palette.ink)
			s.place?.let { p ->
				if (p.hours.isNotEmpty()) Text("Horário: ${p.hours}", style = body(13), color = Palette.muted)
				Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 4.dp)) {
					ChunkyButton("Pedir Uber", { open(p.uberUrl) }, variant = ButtonVariant.Uber, small = true, icon = IconName.Car)
					ChunkyButton("Mapa", { open(p.mapsUrl) }, variant = ButtonVariant.Secondary, small = true, icon = IconName.Pin)
				}
			}
		}
	}
}

private fun transportColor(t: String) = when (t) {
	"onibus", "rodo" -> Palette.sky
	"turismo" -> Palette.leaf
	"uber" -> Palette.plum
	else -> Palette.coral
}
