package com.nelsul.curitibatrip.feature.roteiro

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.background.Notifier
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.Ok
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.feature.feed.EmptyState
import com.nelsul.curitibatrip.feature.mapa.MapStyle
import com.nelsul.curitibatrip.ui.components.AppTextField
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.Chip
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TitleRow
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.Radius
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import com.nelsul.curitibatrip.ui.theme.popIn
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.Normalizer
import java.time.Instant
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private val MONTHS = listOf("JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ")
private val dayMonth = DateTimeFormatter.ofPattern("dd/MM").withZone(TripTime.zone)

/**
 * Roteiro (web /roteiro), the same for everyone and editable by everyone:
 * **Dia a dia** (route map, stops with "Fomos?", Uber and Maps) and **Lugares** (places with photos, hours, prices).
 */
@Composable
fun RoteiroScreen(contentPadding: PaddingValues) {
	val app = LocalApp.current
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	var data by remember { mutableStateOf<RoteiroData?>(null) }
	var style by remember { mutableStateOf<String?>(null) }
	var error by remember { mutableStateOf<String?>(null) }
	var tab by remember { mutableIntStateOf(0) }
	var selected by remember { mutableStateOf<String?>(null) }
	var editingDay by remember { mutableStateOf<Pair<RoteiroDay?, String>?>(null) }
	var editingPlace by remember { mutableStateOf<RoteiroPlace?>(null) }
	var newPlace by remember { mutableStateOf(false) }
	var toast by remember { mutableStateOf<String?>(null) }
	val scroll = rememberScrollState()
	/** each numbered stop's top, in the scrolling column, for "tap a pin → scroll to its stop" */
	val stopY = remember { mutableStateMapOf<Int, Int>() }
	var columnTop by remember { mutableIntStateOf(0) }
	val open: (String) -> Unit = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(it))) }

	suspend fun load() {
		try {
			val d: RoteiroData = Api.get("/api/roteiro")
			data = d
			if (style == null) style = runCatching { MapStyle.json(context) }.getOrNull()
			if (selected == null || d.days.none { it.date == selected }) {
				val today = TripTime.dayKey(Instant.now().toString())
				selected = d.days.firstOrNull { it.date == today }?.date ?: d.days.firstOrNull()?.date
			}
			error = null
		} catch (e: Exception) {
			app.handle(e)
			error = e.message
		}
	}
	fun show(text: String) {
		scope.launch { toast = text; delay(3000); toast = null }
	}
	LaunchedEffect(Unit) { load() }

	val days = data?.days.orEmpty()
	val places = data?.places.orEmpty()
	val day = days.firstOrNull { it.date == selected } ?: days.firstOrNull()
	val placeOf: (String?) -> RoteiroPlace? = { id -> id?.let { i -> places.firstOrNull { it.id == i } } }
	val nextDate = days.lastOrNull()?.let { LocalDate.parse(it.date).plusDays(1).toString() } ?: TripTime.dayKey(Instant.now().toString())

	/** "Fomos!": one tick counts for the whole group. */
	fun toggleVisit(s: RoteiroStop) {
		scope.launch {
			try {
				val r = Api.post<VisitBody, VisitResult>("/api/roteiro/stops/${s.id}/visited", VisitBody(s.visitedAt == null))
				data = data?.let { d ->
					d.copy(days = d.days.map { dd -> dd.copy(stops = dd.stops.map { if (it.id == s.id) it.copy(visitedAt = r.visitedAt, visitedBy = r.visitedBy) else it }) })
				}
			} catch (e: Exception) {
				app.handle(e)
				show(e.message ?: "Não foi possível marcar.")
			}
		}
	}

	/** "Pôr no roteiro": the place becomes the last stop of that day. */
	fun addToDay(p: RoteiroPlace, date: String) {
		val d = days.firstOrNull { it.date == date } ?: return
		val base = DayBody.of(d)
		scope.launch {
			try {
				Api.putJson<DayBody, Ok>("/api/roteiro/days/$date", base.copy(stops = base.stops + DayBody.Stop(null, "", p.id, "", "uber", "")))
				Notifier.itineraryChanged(context)
				load()
				show("${p.name} entrou no roteiro de ${TripTime.shortWeekday(date)} ${date.takeLast(2)}.")
			} catch (e: Exception) {
				app.handle(e)
				show(e.message ?: "Não foi possível salvar.")
			}
		}
	}

	Box(Modifier.fillMaxSize()) {
		Column(
			Modifier.fillMaxSize().verticalScroll(scroll).padding(contentPadding).padding(16.dp)
				.onGloballyPositioned { columnTop = it.positionInRoot().y.toInt() + scroll.value },
			horizontalAlignment = Alignment.CenterHorizontally,
		) {
			Column(Modifier.widthIn(max = 640.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
				TitleRow(IconName.Ticket, "Roteiro")
				Tabs(tab, places.size) { tab = it }
				error?.let { e -> if (data == null) EmptyState(e, retry = { scope.launch { load() } }) }
				if (tab == 0) {
					Row(Modifier.horizontalScroll(rememberScrollState()).padding(vertical = 6.dp, horizontal = 2.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
						days.forEach { d ->
							Chip(d.date == day?.date, { selected = d.date }, dashed = true, tint = if (d.wedding) Palette.berry else null) {
								Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(vertical = 4.dp)) {
									Text(d.date.takeLast(2), style = display(17))
									Text(TripTime.shortWeekday(d.date), style = body(11, FontWeight.ExtraBold))
								}
							}
						}
						Box(Modifier.semantics { contentDescription = "Adicionar dia" }) {
							Chip(false, { editingDay = null to nextDate }, dashed = true, tint = Palette.sea) {
								Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(vertical = 4.dp)) {
									Text("+", style = display(17), color = Palette.sea)
									Text("dia", style = body(11, FontWeight.ExtraBold), color = Palette.sea)
								}
							}
						}
					}
					if (day != null) {
						Ticket(
							day, days.indexOf(day) + 1, days.size, placeOf, style, open,
							onVisit = ::toggleVisit, onEditPlace = { editingPlace = it }, onEdit = { editingDay = day to day.date },
							onPick = { n -> stopY[n]?.let { y -> scope.launch { scroll.animateScrollTo((y - columnTop - 120).coerceAtLeast(0)) } } },
							onStopPlaced = { n, y -> stopY[n] = y + scroll.value },
						)
					} else if (data != null) {
						Column(Modifier.fillMaxWidth().card(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
							Text("O roteiro ainda está vazio.", style = body(16), color = Palette.ink)
							ChunkyButton("Criar o primeiro dia", { editingDay = null to nextDate }, variant = ButtonVariant.Sun)
						}
					}
				} else {
					PlacesTab(places, days, open, onEdit = { editingPlace = it }, onNew = { newPlace = true }, onAdd = ::addToDay)
				}
			}
		}
		AnimatedVisibility(toast != null, Modifier.align(Alignment.TopCenter).padding(16.dp), enter = slideInVertically() + fadeIn(), exit = fadeOut()) {
			Text(toast ?: "", style = body(15, FontWeight.ExtraBold), color = Palette.onLeaf,
				modifier = Modifier.background(Palette.leaf, RoundedCornerShape(14.dp)).padding(horizontal = 14.dp, vertical = 10.dp))
		}
	}

	editingDay?.let { (d, suggested) ->
		DayEditor(d, places, days.map { it.date }, suggested, onDismiss = { editingDay = null },
			saved = { date -> scope.launch { load(); if (date != null) selected = date } }, placesChanged = { scope.launch { load() } })
	}
	editingPlace?.let { p -> PlaceEditor(p, { editingPlace = null }, changed = { scope.launch { load() } }) }
	if (newPlace) PlaceEditor(null, { newPlace = false }, changed = { scope.launch { load() } })
}

/** "Dia a dia" / "Lugares": the sea-blue pill switch (web .tabs). */
@Composable
private fun Tabs(tab: Int, places: Int, onSelect: (Int) -> Unit) {
	Row(
		Modifier.fillMaxWidth().background(Palette.surface, CircleShape).border(2.5.dp, Palette.line, CircleShape).padding(5.dp),
		horizontalArrangement = Arrangement.spacedBy(6.dp),
	) {
		listOf(Triple(0, "Dia a dia", IconName.Calendar), Triple(1, "Lugares ($places)", IconName.Pin)).forEach { (i, label, icon) ->
			val on = tab == i
			Row(
				Modifier
					.weight(1f)
					.heightIn(min = 42.dp)
					.drawBehind {
						if (on) {
							val r = CornerRadius(size.height / 2)
							drawRoundRect(Palette.seaDark, topLeft = Offset(0f, 3.dp.toPx()), size = size, cornerRadius = r)
							drawRoundRect(Palette.sea, cornerRadius = r)
						}
					}
					.pressable({ onSelect(i) })
					.semantics { selected = on },
				horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
			) {
				Icon(icon, if (on) Palette.onSea else Palette.muted, size = 18.dp)
				Spacer(Modifier.width(6.dp))
				Text(label, style = display(16), color = if (on) Palette.onSea else Palette.muted)
			}
		}
	}
}

@Composable
private fun Ticket(
	d: RoteiroDay, index: Int, total: Int, placeOf: (String?) -> RoteiroPlace?, style: String?, open: (String) -> Unit,
	onVisit: (RoteiroStop) -> Unit, onEditPlace: (RoteiroPlace) -> Unit, onEdit: () -> Unit, onPick: (Int) -> Unit, onStopPlaced: (Int, Int) -> Unit,
) {
	val shape = RoundedCornerShape(Radius.card)
	var n = 0
	val numbered = d.stops.map { s -> s to placeOf(s.placeId)?.let { ++n } }
	val points = numbered.mapNotNull { (s, num) ->
		val p = placeOf(s.placeId) ?: return@mapNotNull null
		RoutePoint(num ?: 0, p.name, p.lat, p.lng, p.photos.firstOrNull()?.url, s.visitedAt != null)
	}
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
				Text(d.title.ifEmpty { "Sem título" }, style = display(24), color = Color.White)
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
				Text(MONTHS[((d.date.substring(5, 7).toIntOrNull() ?: 11) - 1).coerceIn(0, 11)], style = body(11, FontWeight.ExtraBold),
					color = Color.White, modifier = Modifier.offset(y = (-4).dp))
			}
		}
		Box(Modifier.fillMaxWidth().padding(horizontal = 14.dp).height(3.dp).drawBehind {
			drawLine(Palette.line, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), 3.dp.toPx(),
				pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 5.dp.toPx())))
		})
		Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
			if (d.who.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
				Icon(IconName.People, Palette.muted, size = 16.dp)
				Text(d.who, style = body(14, FontWeight.Bold), color = Palette.muted)
			}
			if (d.lead.isNotEmpty()) Text(d.lead, style = body(17), color = Palette.ink)
			if (points.isNotEmpty() && style != null) {
				key(d.date) {
					RouteMap(style, d.date, points, Modifier.fillMaxWidth().height(260.dp).clip(RoundedCornerShape(18.dp)).border(2.5.dp, Palette.line, RoundedCornerShape(18.dp)), onPick)
				}
				Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
					RoteiroTransport.entries.filter { t -> d.stops.any { it.transport == t.key } }.forEach { t ->
						Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
							Box(Modifier.size(18.dp, 4.dp).background(t.color, CircleShape))
							Text(t.label, style = body(12, FontWeight.Bold), color = Palette.muted)
						}
					}
				}
			}
			numbered.forEachIndexed { i, (s, num) ->
				StopCard(s, num, placeOf(s.placeId), open, { onVisit(s) }, onEditPlace,
					Modifier.popIn(100L + i * 70L).onGloballyPositioned { if (num != null) onStopPlaced(num, it.positionInRoot().y.toInt()) })
			}
			if (d.stops.isEmpty()) Text("Nenhuma parada ainda.", style = body(15), color = Palette.muted)
			val route = Roteiro.routeUrl(d.stops.mapNotNull { placeOf(it.placeId) })
			if (route != null && !d.wedding) ChunkyButton("Rota do dia no Google Maps", { open(route) }, variant = ButtonVariant.Sea, fullWidth = true, icon = IconName.Map)
			ChunkyButton("✎ Editar este dia", onEdit, variant = ButtonVariant.Secondary, fullWidth = true)
		}
	}
}

@Composable
private fun StopCard(s: RoteiroStop, n: Int?, p: RoteiroPlace?, open: (String) -> Unit, onVisit: () -> Unit, onEditPlace: (RoteiroPlace) -> Unit, modifier: Modifier) {
	val app = LocalApp.current
	val t = RoteiroTransport.of(s.transport)
	val visited = s.visitedAt != null
	Column(
		modifier.fillMaxWidth().background(Palette.surface2.copy(alpha = 0.4f), RoundedCornerShape(18.dp))
			.border(2.5.dp, if (visited) Palette.leaf else Palette.line, RoundedCornerShape(18.dp)).padding(12.dp),
		verticalArrangement = Arrangement.spacedBy(8.dp),
	) {
		Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
			if (p != null) {
				val photo = p.photos.firstOrNull()
				if (photo != null) {
					AsyncImage(photo.url, "Foto de ${p.name}", contentScale = ContentScale.Crop, modifier = Modifier.size(76.dp).clip(RoundedCornerShape(14.dp)))
				} else {
					Column(
						Modifier.size(76.dp).background(p.categoryInfo.color.copy(alpha = 0.18f), RoundedCornerShape(14.dp)).pressable({ onEditPlace(p) })
							.semantics { contentDescription = "Adicionar foto de ${p.name}" },
						horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
					) {
						Icon(IconName.Camera, p.categoryInfo.color, size = 22.dp)
						Text("foto", style = body(11, FontWeight.ExtraBold), color = p.categoryInfo.color)
					}
				}
			}
			Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
				Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
					if (n != null) Box(Modifier.size(24.dp).background(Palette.sun, CircleShape), contentAlignment = Alignment.Center) {
						Text("$n", style = display(13), color = Palette.onSun)
					}
					Text(s.time.ifEmpty { "Sem horário" }, style = display(13), color = if (visited) Palette.onLeaf else Palette.onSun,
						modifier = Modifier.background(if (visited) Palette.leaf else Palette.sun, RoundedCornerShape(10.dp)).padding(horizontal = 10.dp, vertical = 2.dp))
				}
				Text(p?.name ?: s.label, style = display(19), color = Palette.ink)
				Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
					Badge(t.label, t.color)
					if (p != null) Badge(p.categoryInfo.label, p.categoryInfo.color)
				}
			}
		}
		if (s.note.isNotEmpty()) Text(s.note, style = body(15), color = Palette.ink)
		s.visitedAt?.let { at ->
			val who = if (s.visitedBy == app.me?.id) "você" else s.visitedBy?.let { app.person(it)?.name } ?: "alguém"
			val whenText = TripTime.instant(at)?.let { "${dayMonth.format(it)} ${TripTime.time(at)}" } ?: ""
			Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
				Icon(IconName.Check, Palette.leaf, size = 15.dp)
				Text("Fomos! Marcado por $who em $whenText", style = body(14, FontWeight.ExtraBold), color = Palette.leaf)
			}
		}
		if (p != null) {
			if (p.hours.isNotEmpty()) Text("Horário: ${p.hours}", style = body(13), color = Palette.muted)
			if (p.price.isNotEmpty() || p.priceLevel != null) Text("Preço: ${Roteiro.priceSigns(p.priceLevel)} ${p.price}", style = body(13), color = Palette.muted)
			Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
				ChunkyButton("Pedir Uber", { open(p.uberUrl) }, variant = ButtonVariant.Uber, small = true, icon = IconName.Car)
				Box(Modifier.semantics(mergeDescendants = true) { contentDescription = "Abrir no Google Maps" }) {
					ChunkyButton({ open(p.mapsUrl) }, variant = ButtonVariant.Secondary, small = true) { Icon(IconName.Map, Palette.ink, size = 18.dp) }
				}
				Box(Modifier.semantics(mergeDescendants = true) { contentDescription = "Editar lugar" }) {
					ChunkyButton({ onEditPlace(p) }, variant = ButtonVariant.Secondary, small = true) { Text("✎") }
				}
			}
			ChunkyButton(if (visited) "Fomos!" else "Fomos?", onVisit, variant = if (visited) ButtonVariant.Leaf else ButtonVariant.Secondary,
				small = true, fullWidth = true, icon = IconName.Check)
		}
	}
}

@Composable
private fun Badge(text: String, color: Color) {
	Text(text, style = body(12, FontWeight.ExtraBold), color = color,
		modifier = Modifier.border(2.dp, color, CircleShape).padding(horizontal = 9.dp, vertical = 1.dp))
}

// ── Lugares ──

@Composable
private fun PlacesTab(
	places: List<RoteiroPlace>, days: List<RoteiroDay>, open: (String) -> Unit,
	onEdit: (RoteiroPlace) -> Unit, onNew: () -> Unit, onAdd: (RoteiroPlace, String) -> Unit,
) {
	var filter by remember { mutableStateOf<RoteiroCategory?>(null) }
	var query by remember { mutableStateOf("") }
	val fold = { s: String -> Normalizer.normalize(s, Normalizer.Form.NFD).replace(Regex("\\p{M}"), "").lowercase() }
	val q = fold(query.trim())
	val shown = places.filter { p -> (filter == null || p.category == filter?.key) && (q.isEmpty() || fold("${p.name} ${p.address} ${p.description}").contains(q)) }
	val visited = days.flatMap { d -> d.stops.filter { it.visitedAt != null }.mapNotNull { it.placeId } }.toSet()

	Row(Modifier.horizontalScroll(rememberScrollState()).padding(vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
		Chip(filter == null, { filter = null }) { Text("Todos", style = body(15, FontWeight.ExtraBold)) }
		RoteiroCategory.entries.forEach { c -> Chip(filter == c, { filter = c }) { Text(c.plural, style = body(15, FontWeight.ExtraBold)) } }
	}
	Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
		AppTextField(query, { query = it }, "Procurar", Modifier.weight(1f), singleLine = true)
		ChunkyButton("＋ Lugar", onNew, variant = ButtonVariant.Sun, small = true)
	}
	shown.forEach { p ->
		key(p.id) {
			PlaceCard(p, p.id in visited, days.filter { d -> d.stops.any { it.placeId == p.id } }.map { it.date }, days, open, { onEdit(p) }, { onAdd(p, it) })
		}
	}
	if (shown.isEmpty()) Text(if (query.isEmpty()) "Nenhum lugar aqui ainda." else "Nenhum lugar com esse nome.", style = body(15), color = Palette.muted)
}

@Composable
private fun PlaceCard(p: RoteiroPlace, visited: Boolean, usedOn: List<String>, days: List<RoteiroDay>, open: (String) -> Unit, onEdit: () -> Unit, onAdd: (String) -> Unit) {
	var menu by remember { mutableStateOf(false) }
	Column(Modifier.fillMaxWidth().popIn().card(0.dp)) {
		Box(Modifier.fillMaxWidth().aspectRatio(16f / 10f).clip(RoundedCornerShape(topStart = Radius.card, topEnd = Radius.card))) {
			if (p.photos.isEmpty()) {
				Column(Modifier.fillMaxSize().background(Palette.surface2).pressable(onEdit), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
					Icon(IconName.Camera, Palette.muted, size = 26.dp)
					Text("Adicionar fotos", style = body(14, FontWeight.ExtraBold), color = Palette.muted)
				}
			} else {
				val pager = rememberPagerState { p.photos.size }
				HorizontalPager(pager, Modifier.fillMaxSize()) { i -> AsyncImage(p.photos[i].url, if (i == 0) p.name else null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()) }
				if (p.photos.size > 1) Row(Modifier.align(Alignment.BottomCenter).padding(8.dp), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
					repeat(p.photos.size) { i -> Box(Modifier.size(7.dp).background(if (i == pager.currentPage) Color.White else Color.White.copy(alpha = 0.55f), CircleShape)) }
				}
			}
			Text(p.categoryInfo.label, style = body(12, FontWeight.ExtraBold), color = Color.White,
				modifier = Modifier.padding(10.dp).background(p.categoryInfo.color, CircleShape).padding(horizontal = 10.dp, vertical = 2.dp))
			if (visited) Row(
				Modifier.align(Alignment.TopEnd).padding(10.dp).background(Palette.leaf, CircleShape).padding(horizontal = 10.dp, vertical = 2.dp),
				verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp),
			) {
				Icon(IconName.Check, Palette.onLeaf, size = 13.dp)
				Text("Fomos!", style = body(12, FontWeight.ExtraBold), color = Palette.onLeaf)
			}
		}
		Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
			Text(p.name, style = display(20), color = Palette.ink)
			if (p.address.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
				Icon(IconName.Pin, Palette.muted, Modifier.padding(top = 2.dp), size = 14.dp)
				Text(p.address, style = body(13), color = Palette.muted)
			}
			if (p.hours.isNotEmpty()) InfoRow("Horário") { Text(p.hours, style = body(15), color = Palette.ink) }
			if (p.price.isNotEmpty() || p.priceLevel != null) InfoRow("Preço") {
				Text(buildAnnotatedString {
					withStyle(SpanStyle(color = Palette.sun, fontWeight = FontWeight.ExtraBold)) { append(Roteiro.priceSigns(p.priceLevel)) }
					append(" ${p.price}")
				}, style = body(15), color = Palette.ink)
			}
			if (p.description.isNotEmpty()) Text(p.description, style = body(15), color = Palette.ink)
			if (usedOn.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
				Icon(IconName.Ticket, Palette.leaf, size = 14.dp)
				Text("No roteiro: " + usedOn.joinToString(", ") { "${TripTime.shortWeekday(it)} ${it.takeLast(2)}" }, style = body(13, FontWeight.Bold), color = Palette.leaf)
			}
			Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 4.dp)) {
				ChunkyButton("Pedir Uber", { open(p.uberUrl) }, variant = ButtonVariant.Uber, small = true, icon = IconName.Car)
				ChunkyButton("Maps", { open(p.mapsUrl) }, variant = ButtonVariant.Secondary, small = true, icon = IconName.Map)
				if (p.link.isNotEmpty()) Box(Modifier.semantics(mergeDescendants = true) { contentDescription = "Site ou Instagram" }) {
					ChunkyButton({ open(if (p.link.startsWith("http")) p.link else "https://${p.link}") }, variant = ButtonVariant.Secondary, small = true) {
						Icon(IconName.Expand, Palette.ink, size = 16.dp)
					}
				}
			}
			Row(Modifier.fillMaxWidth().heightIn(min = 44.dp), verticalAlignment = Alignment.CenterVertically) {
				Box {
					Text("+ Pôr no roteiro…", style = body(14, FontWeight.ExtraBold), color = Palette.sea, modifier = Modifier.pressable({ menu = true }).padding(vertical = 8.dp))
					DropdownMenu(menu, { menu = false }, containerColor = Palette.surface) {
						days.forEach { d ->
							DropdownMenuItem(
								text = { Text("${TripTime.shortWeekday(d.date)} ${d.date.takeLast(2)} · ${d.title}", style = body(15), color = Palette.ink) },
								onClick = { menu = false; onAdd(d.date) },
							)
						}
					}
				}
				Spacer(Modifier.weight(1f))
				Text("Editar", style = body(15, FontWeight.ExtraBold), color = Palette.sea, modifier = Modifier.pressable(onEdit).padding(8.dp))
			}
		}
	}
}

@Composable
private fun InfoRow(label: String, value: @Composable () -> Unit) {
	Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
		Text(label, style = body(13, FontWeight.ExtraBold), color = Palette.muted, modifier = Modifier.width(60.dp))
		value()
	}
}
