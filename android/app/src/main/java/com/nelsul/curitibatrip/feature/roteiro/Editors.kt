package com.nelsul.curitibatrip.feature.roteiro

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.background.Notifier
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.Ok
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.feature.mapa.LocationPicker
import com.nelsul.curitibatrip.ui.components.AppTextField
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.Chip
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.ConfirmDialog
import com.nelsul.curitibatrip.ui.components.DottedBackground
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.maplibre.android.geometry.LatLng
import java.io.ByteArrayOutputStream
import java.time.LocalDate

// ── shared pieces ──

/** A full-screen editor page: title, Cancelar / Salvar, scrolling body. */
@Composable
private fun EditorPage(title: String, busy: Boolean, onDismiss: () -> Unit, onSave: () -> Unit, content: @Composable () -> Unit) {
	Dialog(onDismiss, DialogProperties(usePlatformDefaultWidth = false)) {
		Box(Modifier.fillMaxSize()) {
			DottedBackground()
			Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().imePadding()) {
				Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
					ChunkyButton("Cancelar", onDismiss, variant = ButtonVariant.Secondary, small = true)
					Text(title, style = display(20), color = Palette.ink, modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
						textAlign = androidx.compose.ui.text.style.TextAlign.Center)
					ChunkyButton(if (busy) "Salvando…" else "Salvar", onSave, variant = ButtonVariant.Sun, small = true, enabled = !busy)
				}
				Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
					content()
				}
			}
		}
	}
}

@Composable
private fun Field(label: String, content: @Composable () -> Unit) {
	Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
		Text(label, style = body(14, FontWeight.ExtraBold), color = Palette.muted)
		content()
	}
}

/** Photos are shrunk to 1600 px JPEG on the phone before sending (fast uploads, still sharp). */
private suspend fun shrink(context: Context, uri: Uri, max: Int = 1600): ByteArray? = withContext(Dispatchers.IO) {
	runCatching {
		val bmp = ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri)) { d, info, _ ->
			val s = minOf(1f, max.toFloat() / maxOf(info.size.width, info.size.height))
			d.setTargetSize((info.size.width * s).toInt().coerceAtLeast(1), (info.size.height * s).toInt().coerceAtLeast(1))
			d.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
		}
		ByteArrayOutputStream().use { out -> bmp.compress(Bitmap.CompressFormat.JPEG, 85, out); out.toByteArray() }
	}.getOrNull()
}

// ── place editor ──

/** New or existing place (web PlaceEditor). Everyone can edit the shared places. */
@Composable
fun PlaceEditor(place: RoteiroPlace?, onDismiss: () -> Unit, changed: () -> Unit, created: ((String) -> Unit)? = null) {
	val app = LocalApp.current
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	var name by remember { mutableStateOf(place?.name ?: "") }
	var category by remember { mutableStateOf(place?.categoryInfo ?: RoteiroCategory.Comer) }
	var at by remember { mutableStateOf(place?.let { LatLng(it.lat, it.lng) }) }
	var address by remember { mutableStateOf(place?.address ?: "") }
	var hours by remember { mutableStateOf(place?.hours ?: "") }
	var price by remember { mutableStateOf(place?.price ?: "") }
	var priceLevel by remember { mutableStateOf(place?.priceLevel) }
	var description by remember { mutableStateOf(place?.description ?: "") }
	var link by remember { mutableStateOf(place?.link ?: "") }
	val photos = remember { mutableStateListOf<PlacePhoto>().apply { addAll(place?.photos.orEmpty()) } }
	/** photos chosen before a new place exists: sent right after it's created */
	val pending = remember { mutableStateListOf<ByteArray>() }
	var uploading by remember { mutableIntStateOf(0) }
	var picking by remember { mutableStateOf(false) }
	var busy by remember { mutableStateOf(false) }
	var error by remember { mutableStateOf<String?>(null) }
	var confirmDelete by remember { mutableStateOf(false) }

	suspend fun upload(datas: List<ByteArray>, id: String) {
		error = null
		uploading += datas.size
		for (d in datas) {
			try {
				photos += Api.postBytes<PlacePhoto>("/api/roteiro/places/$id/photos", d, "image/jpeg")
			} catch (e: Exception) {
				app.handle(e)
				error = e.message
			}
			uploading--
		}
		changed()
	}

	val pickPhotos = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(10)) { uris ->
		if (uris.isEmpty()) return@rememberLauncherForActivityResult
		scope.launch {
			val datas = uris.mapNotNull { shrink(context, it) }
			if (place != null) upload(datas, place.id) else pending += datas
		}
	}

	fun save() = scope.launch {
		val c = at ?: run { error = "Marque o lugar no mapa (busque pelo nome ou arraste o mapa)."; return@launch }
		busy = true
		error = null
		val body = PlaceBody(name, category.key, c.latitude, c.longitude, address, hours, price, priceLevel, description, link)
		try {
			if (place != null) {
				Api.patch<PlaceBody, Ok>("/api/roteiro/places/${place.id}", body)
			} else {
				val made = Api.post<PlaceBody, CreatedPlace>("/api/roteiro/places", body)
				created?.invoke(made.id)
				if (pending.isNotEmpty()) upload(pending.toList(), made.id)
			}
			changed()
			if (error == null) onDismiss()
		} catch (e: Exception) {
			app.handle(e)
			error = e.message
		} finally {
			busy = false
		}
	}

	EditorPage(if (place == null) "Novo lugar" else "Editar lugar", busy || uploading > 0, onDismiss, { save() }) {
		Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
			RoteiroCategory.entries.forEach { c -> Chip(category == c, { category = c }, tint = c.color) { Text(c.label, style = body(15, FontWeight.ExtraBold)) } }
		}
		Field("Onde fica") {
			Row(
				Modifier.fillMaxWidth().card(padding = 14.dp, radius = 16.dp).pressable({ picking = true }),
				verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
			) {
				Icon(IconName.Pin, Palette.coral, size = 18.dp)
				Text(at?.let { "%.5f, %.5f".format(it.latitude, it.longitude) } ?: "Buscar ou marcar no mapa",
					style = body(16, FontWeight.Bold), color = if (at == null) Palette.sea else Palette.ink, modifier = Modifier.weight(1f))
				if (at != null) Text("Mudar", style = body(15, FontWeight.ExtraBold), color = Palette.sea)
			}
		}
		Field("Nome") { AppTextField(name, { name = it }, "Ex.: Bar do Alemão", Modifier.fillMaxWidth(), singleLine = true) }
		Field("Endereço") { AppTextField(address, { address = it }, "Rua, bairro", Modifier.fillMaxWidth(), singleLine = true) }
		Field("Horário de funcionamento") { AppTextField(hours, { hours = it }, "Ex.: ter–sáb 11h–23h; fecha seg", Modifier.fillMaxWidth()) }
		Field("Faixa de preço") {
			Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
				listOf(null to "Não sei", 0 to "Grátis", 1 to "$", 2 to "$$", 3 to "$$$", 4 to "$$$$").forEach { (v, l) ->
					Chip(priceLevel == v, { priceLevel = v }) { Text(l, style = body(15, FontWeight.ExtraBold)) }
				}
			}
		}
		Field("Preço") { AppTextField(price, { price = it }, "R$ 60–90 por pessoa", Modifier.fillMaxWidth(), singleLine = true) }
		Field("Sobre") { AppTextField(description, { description = it }, "O que pedir, dicas, reservas…", Modifier.fillMaxWidth().heightIn(min = 96.dp), minLines = 3) }
		Field("Site ou Instagram") { AppTextField(link, { link = it }, "https://", Modifier.fillMaxWidth(), singleLine = true) }
		Field("Fotos") {
			Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
				photos.forEach { ph ->
					Box(Modifier.size(88.dp).clip(RoundedCornerShape(12.dp))) {
						AsyncImage(ph.url, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
						Box(
							Modifier.align(Alignment.TopEnd).padding(4.dp).size(28.dp).background(Color.Black.copy(alpha = 0.6f), CircleShape)
								.pressable({
									scope.launch {
										try {
											Api.delete("/api/roteiro/places/${place!!.id}/photos/${ph.id}")
											photos.remove(ph)
											changed()
										} catch (e: Exception) { app.handle(e); error = e.message }
									}
								})
								.semantics { contentDescription = "Apagar foto" },
							contentAlignment = Alignment.Center,
						) { Text("✕", color = Color.White, style = body(13, FontWeight.ExtraBold)) }
					}
				}
				pending.forEach { d ->
					AsyncImage(d, null, contentScale = ContentScale.Crop, modifier = Modifier.size(88.dp).clip(RoundedCornerShape(12.dp)))
				}
				repeat(uploading) {
					Box(Modifier.size(88.dp).background(Palette.surface2, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
						CircularProgressIndicator(Modifier.size(24.dp), color = Palette.sea, strokeWidth = 2.dp)
					}
				}
				Column(
					Modifier.size(88.dp).dashedBorder().pressable({ pickPhotos.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }),
					horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
				) {
					Icon(IconName.Camera, Palette.muted, size = 24.dp)
					Text("Adicionar", style = body(12, FontWeight.ExtraBold), color = Palette.muted)
				}
			}
		}
		error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }
		if (place != null) ChunkyButton("Apagar lugar", { confirmDelete = true }, variant = ButtonVariant.Danger, small = true)
	}

	if (picking) LocationPicker(at, { picking = false }, onPick = { r ->
		if (name.isBlank()) name = r.name
		if (address.isBlank() && r.detail.isNotEmpty() && r.detail != "Lugar da viagem") address = r.detail.replace(" · ", ", ")
	}) { c -> at = c }
	if (confirmDelete) ConfirmDialog("Apagar \"${place?.name}\" para todo mundo? Se estiver no roteiro, a parada fica só com o nome.", "Apagar", { confirmDelete = false }) {
		scope.launch {
			try {
				Api.delete("/api/roteiro/places/${place!!.id}")
				changed()
				onDismiss()
			} catch (e: Exception) { app.handle(e); error = e.message }
		}
	}
}

private fun Modifier.dashedBorder(): Modifier = drawBehind {
	drawRoundRect(
		Palette.line,
		cornerRadius = CornerRadius(12.dp.toPx()),
		style = Stroke(2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx()))),
	)
}

// ── day editor ──

private class EditStop(
	val stopId: String?,
	useClock: Boolean,
	minutes: Int,
	text: String,
	placeId: String?,
	label: String,
	transport: RoteiroTransport,
	note: String,
) {
	val key = java.util.UUID.randomUUID().toString()
	var useClock by mutableStateOf(useClock)
	var minutes by mutableIntStateOf(minutes)
	var text by mutableStateOf(text)
	var placeId by mutableStateOf(placeId)
	var label by mutableStateOf(label)
	var transport by mutableStateOf(transport)
	var note by mutableStateOf(note)
}

/** Edits a whole day (web DayEditor). Saving replaces the day for everyone; ticks stay with their stops. */
@Composable
fun DayEditor(
	day: RoteiroDay?,
	places: List<RoteiroPlace>,
	takenDates: List<String>,
	suggestedDate: String,
	onDismiss: () -> Unit,
	saved: (String?) -> Unit,
	placesChanged: () -> Unit,
) {
	val app = LocalApp.current
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	var date by remember { mutableStateOf(day?.date ?: suggestedDate) }
	var title by remember { mutableStateOf(day?.title ?: "") }
	var who by remember { mutableStateOf(day?.who ?: "") }
	var lead by remember { mutableStateOf(day?.lead ?: "") }
	var wedding by remember { mutableStateOf(day?.wedding ?: false) }
	val stops = remember {
		mutableStateListOf<EditStop>().apply {
			day?.stops?.forEach { s ->
				val m = Roteiro.minutes(s.time)
				add(EditStop(s.id, m != null || s.time.isEmpty(), m ?: 600, if (m == null) s.time else "", s.placeId, s.label, RoteiroTransport.of(s.transport), s.note))
			}
		}
	}
	var busy by remember { mutableStateOf(false) }
	var error by remember { mutableStateOf<String?>(null) }
	var confirmDelete by remember { mutableStateOf(false) }
	var choosingFor by remember { mutableStateOf<EditStop?>(null) }
	var newPlaceFor by remember { mutableStateOf<EditStop?>(null) }

	fun save() = scope.launch {
		if (day == null && date in takenDates) { error = "Esse dia já existe no roteiro. Escolha outra data ou edite o dia."; return@launch }
		busy = true
		error = null
		val body = DayBody(title, who, lead, wedding, stops.map { s ->
			DayBody.Stop(s.stopId, if (s.useClock) Roteiro.timeText(s.minutes) else s.text.trim(), s.placeId, if (s.placeId == null) s.label else "", s.transport.key, s.note)
		})
		try {
			Api.putJson<DayBody, Ok>("/api/roteiro/days/$date", body)
			Notifier.itineraryChanged(context)
			saved(date)
			onDismiss()
		} catch (e: Exception) {
			app.handle(e)
			error = e.message
		} finally {
			busy = false
		}
	}

	EditorPage(if (day == null) "Novo dia" else "Editar dia", busy, onDismiss, { save() }) {
		if (day == null) {
			Field("Data") {
				Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
					ChunkyButton("−", { date = LocalDate.parse(date).minusDays(1).toString() }, variant = ButtonVariant.Secondary, small = true)
					Text("${TripTime.shortWeekday(date)} ${date.takeLast(2)}/${date.substring(5, 7)}/${date.take(4)}", style = display(18), color = Palette.ink,
						modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
					ChunkyButton("+", { date = LocalDate.parse(date).plusDays(1).toString() }, variant = ButtonVariant.Secondary, small = true)
				}
			}
		}
		Field("Título do dia") { AppTextField(title, { title = it }, "Ex.: Mercado, parques e museu", Modifier.fillMaxWidth(), singleLine = true) }
		Field("Quem vai") { AppTextField(who, { who = it }, "Ex.: Todos juntos", Modifier.fillMaxWidth(), singleLine = true) }
		Field("Resumo / dica do dia") { AppTextField(lead, { lead = it }, "", Modifier.fillMaxWidth(), minLines = 2) }
		Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
			Chip(wedding, { wedding = !wedding }, tint = Palette.berry) { Text(if (wedding) "✓ Dia do casamento" else "Dia do casamento", style = body(15, FontWeight.ExtraBold)) }
		}
		Text("Paradas", style = display(20), color = Palette.ink)
		stops.forEachIndexed { i, s ->
			Column(Modifier.fillMaxWidth().card(padding = 12.dp, radius = 18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
				Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
					Box(Modifier.size(28.dp).background(Palette.sun, CircleShape), contentAlignment = Alignment.Center) {
						Text("${i + 1}", style = display(14), color = Palette.onSun)
					}
					if (s.useClock) {
						ChunkyButton("−", { s.minutes = (s.minutes - 15 + 1440) % 1440 }, variant = ButtonVariant.Secondary, small = true)
						Text(Roteiro.timeText(s.minutes), style = display(18), color = Palette.ink)
						ChunkyButton("+", { s.minutes = (s.minutes + 15) % 1440 }, variant = ButtonVariant.Secondary, small = true)
					} else {
						AppTextField(s.text, { s.text = it }, "Ex.: Ida e volta", Modifier.weight(1f), singleLine = true)
					}
					Spacer(Modifier.weight(if (s.useClock) 1f else 0.01f))
					Text(if (s.useClock) "texto" else "hora", style = body(13, FontWeight.ExtraBold), color = Palette.sea,
						modifier = Modifier.pressable({ s.useClock = !s.useClock }).padding(6.dp))
				}
				val p = places.firstOrNull { it.id == s.placeId }
				Row(
					Modifier.fillMaxWidth().border(2.5.dp, Palette.line, RoundedCornerShape(16.dp)).pressable({ choosingFor = s }).padding(12.dp),
					verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
				) {
					Icon(IconName.Pin, p?.categoryInfo?.color ?: Palette.muted, size = 18.dp)
					Text(p?.name ?: "Sem lugar (só texto)", style = body(16, FontWeight.Bold), color = if (p != null) Palette.ink else Palette.muted, modifier = Modifier.weight(1f))
					Text("Trocar", style = body(14, FontWeight.ExtraBold), color = Palette.sea)
				}
				if (s.placeId == null) AppTextField(s.label, { s.label = it }, "O que é? (ex.: Salão do casamento)", Modifier.fillMaxWidth(), singleLine = true)
				Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
					RoteiroTransport.entries.forEach { t -> Chip(s.transport == t, { s.transport = t }, tint = t.color) { Text(t.label, style = body(14, FontWeight.ExtraBold)) } }
				}
				AppTextField(s.note, { s.note = it }, "Dicas, o que fazer lá…", Modifier.fillMaxWidth(), minLines = 2)
				Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
					Spacer(Modifier.weight(1f))
					ChunkyButton("↑ Subir", { stops.add(i - 1, stops.removeAt(i)) }, variant = ButtonVariant.Secondary, small = true, enabled = i > 0)
					ChunkyButton("↓ Descer", { stops.add(i + 1, stops.removeAt(i)) }, variant = ButtonVariant.Secondary, small = true, enabled = i < stops.size - 1)
					ChunkyButton("✕", { stops.removeAt(i) }, variant = ButtonVariant.Danger, small = true)
				}
			}
		}
		ChunkyButton("Adicionar parada", {
			stops += EditStop(null, true, ((stops.lastOrNull()?.minutes ?: 480) + 120) % 1440, "", null, "", if (stops.isEmpty()) RoteiroTransport.Pe else RoteiroTransport.Uber, "")
		}, variant = ButtonVariant.Secondary, fullWidth = true, icon = IconName.Pin)
		Text("Com horário, o app avisa 30 min antes. A rota no mapa segue a ordem das paradas.", style = body(13), color = Palette.muted)
		error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }
		if (day != null) ChunkyButton("Apagar dia", { confirmDelete = true }, variant = ButtonVariant.Danger, small = true)
	}

	choosingFor?.let { s ->
		PlaceChooser(places, onDismiss = { choosingFor = null }, onChoose = { id -> s.placeId = id; choosingFor = null }, onNew = { choosingFor = null; newPlaceFor = s })
	}
	newPlaceFor?.let { s -> PlaceEditor(null, { newPlaceFor = null }, placesChanged, created = { id -> s.placeId = id }) }
	if (confirmDelete) ConfirmDialog("Apagar este dia do roteiro para todo mundo?", "Apagar", { confirmDelete = false }) {
		scope.launch {
			try {
				Api.delete("/api/roteiro/days/${day!!.date}")
				Notifier.itineraryChanged(context)
				saved(null)
				onDismiss()
			} catch (e: Exception) { app.handle(e); error = e.message }
		}
	}
}

/** Pick the place of a stop (grouped by type), "Sem lugar", or create a new one. */
@Composable
private fun PlaceChooser(places: List<RoteiroPlace>, onDismiss: () -> Unit, onChoose: (String?) -> Unit, onNew: () -> Unit) {
	var query by remember { mutableStateOf("") }
	Dialog(onDismiss) {
		Column(Modifier.fillMaxWidth().heightIn(max = 560.dp).card(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
			Text("Escolher lugar", style = display(20), color = Palette.ink)
			AppTextField(query, { query = it }, "Procurar", Modifier.fillMaxWidth(), singleLine = true)
			Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(2.dp)) {
				Row(Modifier.fillMaxWidth().pressable({ onNew() }).padding(10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
					Text("＋ Cadastrar lugar novo…", style = body(16, FontWeight.ExtraBold), color = Palette.sea)
				}
				Row(Modifier.fillMaxWidth().pressable({ onChoose(null) }).padding(10.dp)) {
					Text("Sem lugar (só texto)", style = body(16, FontWeight.Bold), color = Palette.muted)
				}
				val q = query.trim().lowercase()
				RoteiroCategory.entries.forEach { c ->
					val list = places.filter { it.category == c.key && (q.isEmpty() || it.name.lowercase().contains(q)) }
					if (list.isNotEmpty()) {
						Text(c.plural, style = body(13, FontWeight.ExtraBold), color = c.color, modifier = Modifier.padding(top = 8.dp, start = 10.dp))
						list.forEach { p ->
							Row(Modifier.fillMaxWidth().heightIn(min = 44.dp).pressable({ onChoose(p.id) }).padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
								Text(p.name, style = body(16, FontWeight.Bold), color = Palette.ink)
							}
						}
					}
				}
			}
		}
	}
}
