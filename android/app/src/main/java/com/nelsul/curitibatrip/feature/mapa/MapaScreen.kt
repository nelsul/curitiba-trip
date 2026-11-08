package com.nelsul.curitibatrip.feature.mapa

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.CheckinBody
import com.nelsul.curitibatrip.data.Created
import com.nelsul.curitibatrip.data.LatestLocation
import com.nelsul.curitibatrip.data.LocationOnce
import com.nelsul.curitibatrip.data.LocationSharing
import com.nelsul.curitibatrip.data.MapData
import com.nelsul.curitibatrip.data.Route
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.feature.feed.EmptyState
import com.nelsul.curitibatrip.ui.components.AppTextField
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.CardDialog
import com.nelsul.curitibatrip.ui.components.Chip
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.DottedBackground
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TitleRow
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.Radius
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import com.nelsul.curitibatrip.ui.theme.popIn
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.maplibre.android.geometry.LatLng
import java.time.Instant

/** Mapa (web /mapa): located photos, check-ins, trails and latest positions, with filters, sharing and check-in. */
@Composable
fun MapaScreen(contentPadding: PaddingValues, open: (Route) -> Unit, checkinRequests: Int = 0) {
	val app = LocalApp.current
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	val controller = remember { MapController() }
	var style by remember { mutableStateOf<String?>(null) }
	var data by remember { mutableStateOf<MapData?>(null) }
	var error by remember { mutableStateOf<String?>(null) }
	val today = TripTime.dayKey(Instant.now().toString())
	var day by remember { mutableStateOf(if (today in TripTime.tripDays) today else null) }
	var person by remember { mutableStateOf<String?>(null) }
	var showFilters by remember { mutableStateOf(false) }
	var checkingIn by remember { mutableStateOf(false) }
	var stamp by remember { mutableStateOf<Instant?>(null) }
	var ready by remember { mutableStateOf(false) }
	var fitToken by remember { mutableIntStateOf(0) }
	markerColors = app.people.associate { it.id to colorOf(it.color) }

	fun visible(d: String, u: String) = (day == null || d == day) && (person == null || u == person)
	val items = data?.items.orEmpty().filter { it.lat != null && visible(it.day, it.userId) }
	val people = data?.latest.orEmpty().filter { person == null || it.userId == person }
	val trails = remember(data, day, person) {
		val pts = data?.pings.orEmpty().filter { visible(it.day, it.userId) }.map { Triple(it.userId, it.day, it.at) to LatLng(it.lat, it.lng) } +
			items.map { Triple(it.userId, it.day, it.at) to LatLng(it.lat!!, it.lng!!) }
		pts.sortedBy { it.first.third }.groupBy { it.first.first + "|" + it.first.second }
			.filterValues { it.size > 1 }
			.map { (k, v) -> val uid = k.substringBefore('|'); Trail(uid, app.person(uid)?.color ?: "#888888", v.map { it.second }) }
	}
	val days = (TripTime.tripDays + data?.items.orEmpty().map { it.day }).distinct().sorted()

	suspend fun load(fit: Boolean = true) {
		try {
			if (style == null) style = MapStyle.json(context)
			data = Api.get("/api/map")
			error = null
			if (fit) fitToken++
		} catch (e: Exception) {
			app.handle(e)
			if (data == null) error = e.message
		}
	}
	LaunchedEffect(Unit) { load() }
	LaunchedEffect(app.feedVersion) { if (data != null) load(fit = false) }
	LaunchedEffect(day, person) { fitToken++ }
	LaunchedEffect(fitToken, ready) {
		if (ready) controller.fit(items.map { LatLng(it.lat!!, it.lng!!) } + people.map { LatLng(it.lat, it.lng) })
	}
	// everyone's latest position, every 20 s while the map is open
	LaunchedEffect(Unit) {
		while (true) {
			delay(20_000)
			runCatching { Api.get<List<LatestLocation>>("/api/locations") }.getOrNull()?.let { l -> data = data?.copy(latest = l) }
		}
	}
	// "Chegou em …? Fazer check-in" notification
	LaunchedEffect(checkinRequests) { if (checkinRequests > 0) checkingIn = true }

	val locationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { granted ->
		if (granted.values.any { it }) LocationSharing.start() else LocationSharing.error = "Sem permissão de localização. Ative nas configurações do app."
	}

	Box(Modifier.fillMaxSize().padding(contentPadding)) {
		val s = style
		when {
			s != null -> TripMap(
				s, controller,
				Modifier.fillMaxSize().padding(10.dp).clip(RoundedCornerShape(Radius.card)).border(3.dp, Palette.line, RoundedCornerShape(Radius.card)),
				items = items, trails = trails, people = people,
				onReady = { ready = true },
				onOpenItem = { open(if (it.type == "checkin") Route.Checkin(it.id) else Route.Media(it.id)) },
			)
			error != null -> Box(Modifier.fillMaxSize().padding(20.dp), contentAlignment = Alignment.Center) { EmptyState(error!!, retry = { scope.launch { load() } }) }
			else -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Palette.sea) }
		}
		// filters and actions belong to the map: only once it has loaded
		if (s != null) {
			Column(Modifier.padding(22.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
				ChunkyButton({ showFilters = !showFilters }, variant = ButtonVariant.Secondary, small = true) {
					Icon(IconName.Calendar, Palette.ink, size = 18.dp)
					Text("Filtros" + if (day != null || person != null) " •" else "")
				}
				AnimatedVisibility(showFilters, enter = scaleIn(initialScale = 0.6f) + fadeIn(), exit = fadeOut()) {
					Column(Modifier.card(padding = 10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
						Row(Modifier.horizontalScroll(rememberScrollState()).padding(vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
							Chip(day == null, { day = null }) { Text("Todos os dias", style = body(15, FontWeight.ExtraBold)) }
							days.forEach { d -> Chip(day == d, { day = d }, dashed = true) { Text(d.takeLast(2) + "/" + d.substring(5, 7), style = body(15, FontWeight.ExtraBold)) } }
						}
						Row(Modifier.horizontalScroll(rememberScrollState()).padding(vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
							Chip(person == null, { person = null }) {
								Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
									Icon(IconName.People, LocalContentColor.current, size = 16.dp)
									Text("Todo mundo", style = body(15, FontWeight.ExtraBold))
								}
							}
							app.people.forEach { p -> Chip(person == p.id, { person = p.id }, tint = colorOf(p.color)) { Text(p.name, style = body(15, FontWeight.ExtraBold)) } }
						}
					}
				}
			}
			Column(Modifier.align(Alignment.BottomCenter).padding(horizontal = 22.dp, vertical = 26.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
				LocationSharing.error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger, modifier = Modifier.card(padding = 10.dp)) }
				Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
					if (LocationSharing.sharing) ChunkyButton({ LocationSharing.stop() }, variant = ButtonVariant.Leaf) {
						Box(Modifier.size(10.dp).background(Color.White, CircleShape))
						Text("Compartilhando")
					} else ChunkyButton("Compartilhar local", {
						if (LocationOnce.allowed(context)) LocationSharing.start()
						else locationPermission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
					}, variant = ButtonVariant.Secondary, icon = IconName.People)
					ChunkyButton("Check-in", { checkingIn = true }, variant = ButtonVariant.Sun, icon = IconName.Pin)
				}
			}
		}
		AnimatedVisibility(stamp != null, Modifier.align(Alignment.Center).offset(y = (-60).dp), enter = scaleIn(initialScale = 2.4f) + fadeIn(), exit = fadeOut()) {
			Column(
				Modifier.rotate(-8f).size(150.dp).background(Color(0xE0FFFCF0), CircleShape).border(2.dp, Palette.coral, CircleShape).padding(3.dp).border(2.dp, Palette.coral, CircleShape),
				horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
			) {
				Text("CHECK-IN", style = display(24), color = Palette.coral)
				Text(stamp?.let { TripTime.time(it.toString()) } ?: "", style = body(12, FontWeight.Bold), color = Palette.coral)
			}
		}
	}

	if (checkingIn) CheckinDialog(controller, onDismiss = { checkingIn = false }) { lat, lng ->
		if (day != null && day != today) day = today
		load(fit = false)
		app.feedChanged()
		stamp = Instant.now()
		scope.launch { delay(2600); stamp = null }
	}
}

/** "Check-in": a note, then a pin where you are, on the map and in everyone's diary. */
@Composable
private fun CheckinDialog(controller: MapController, onDismiss: () -> Unit, done: suspend (Double, Double) -> Unit) {
	val app = LocalApp.current
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	var note by remember { mutableStateOf("") }
	var busy by remember { mutableStateOf(false) }
	var error by remember { mutableStateOf<String?>(null) }
	fun go() = scope.launch {
		busy = true
		error = null
		try {
			val recent = LocationSharing.last?.takeIf { System.currentTimeMillis() - it.time < 30_000 }
			val l = recent ?: LocationOnce.current(context)
			val body = CheckinBody(l.latitude, l.longitude, l.accuracy.toDouble(), note.trim())
			val created: Created = Api.post("/api/checkins", body)
			// the map picture for the diary is made in the background; the feed shows a banner meanwhile
			app.me?.let { me -> CheckinSnapshot.attachInBackground(context, controller, created.id, body.lat, body.lng, me) { app.feedChanged() } }
			onDismiss()
			done(body.lat, body.lng)
		} catch (e: Exception) {
			app.handle(e)
			error = e.message ?: "Não foi possível salvar o check-in."
		} finally { busy = false }
	}
	val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { granted ->
		if (granted.values.any { it }) go() else error = "Sem permissão de localização. Ative nas configurações do app."
	}
	CardDialog(onDismiss) {
		TitleRow(IconName.Pin, "Check-in")
		Text("Crava um alfinete onde você está agora, no mapa e no diário de todo mundo.", style = body(15), color = Palette.muted)
		AppTextField(note, { note = it }, "O que está rolando? (opcional)", Modifier.fillMaxWidth().heightIn(min = 90.dp), minLines = 3)
		error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }
		Row(verticalAlignment = Alignment.CenterVertically) {
			ChunkyButton("Cancelar", onDismiss, variant = ButtonVariant.Secondary)
			Spacer(Modifier.weight(1f))
			ChunkyButton(if (busy) "Localizando…" else "Fazer check-in", {
				if (LocationOnce.allowed(context)) go() else permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
			}, variant = ButtonVariant.Sun, enabled = !busy)
		}
	}
}

/** Pick a spot on the map ("Marcar no mapa" / "Corrigir" on your own photos). */
@Composable
fun LocationPicker(start: LatLng?, onDismiss: () -> Unit, save: suspend (LatLng) -> Unit) {
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	val controller = remember { MapController() }
	var style by remember { mutableStateOf<String?>(null) }
	var center by remember { mutableStateOf<LatLng?>(start) }
	var busy by remember { mutableStateOf(false) }
	var error by remember { mutableStateOf<String?>(null) }
	LaunchedEffect(Unit) { runCatching { MapStyle.json(context) }.onSuccess { style = it }.onFailure { error = it.message } }
	Dialog(onDismiss, DialogProperties(usePlatformDefaultWidth = false)) {
		Box(Modifier.fillMaxSize()) {
			DottedBackground()
			Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
				Text("Arraste o mapa até o lugar da foto", style = display(20), color = Palette.ink, modifier = Modifier.padding(top = 18.dp).align(Alignment.CenterHorizontally))
				Box(Modifier.weight(1f).fillMaxWidth().clip(RoundedCornerShape(Radius.card)).border(3.dp, Palette.line, RoundedCornerShape(Radius.card)), contentAlignment = Alignment.Center) {
					val s = style
					if (s != null) TripMap(s, controller, Modifier.fillMaxSize(),
						initial = start ?: LocationSharing.last?.let { LatLng(it.latitude, it.longitude) } ?: LatLng(-25.4284, -49.2733),
						initialZoom = if (start == null) 13.0 else 16.0,
						onCameraIdle = { center = it })
					else CircularProgressIndicator(color = Palette.sea)
					PinMarker(Palette.coral, Modifier.offset(y = (-28).dp))
				}
				error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }
				Row(verticalAlignment = Alignment.CenterVertically) {
					ChunkyButton("Cancelar", onDismiss, variant = ButtonVariant.Secondary)
					Spacer(Modifier.weight(1f))
					ChunkyButton(if (busy) "Salvando…" else "Usar este lugar", {
						val c = center ?: return@ChunkyButton
						scope.launch {
							busy = true
							try { save(c); onDismiss() } catch (e: Exception) { error = e.message } finally { busy = false }
						}
					}, variant = ButtonVariant.Sun, enabled = !busy && center != null)
				}
			}
		}
	}
}

