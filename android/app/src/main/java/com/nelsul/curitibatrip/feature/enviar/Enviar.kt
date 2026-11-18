package com.nelsul.curitibatrip.feature.enviar

import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import android.content.Context
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.border
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.withStyle
import androidx.compose.runtime.saveable.rememberSaveable
import android.provider.MediaStore
import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.format.Formatter
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.data.LocationOnce
import com.nelsul.curitibatrip.data.Route
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.ui.components.AppTextField
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TextLink
import com.nelsul.curitibatrip.ui.components.TitleRow
import com.nelsul.curitibatrip.ui.components.UploadFlight
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.Radius
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import com.nelsul.curitibatrip.ui.theme.popIn
import com.nelsul.curitibatrip.upload.MediaReader
import com.nelsul.curitibatrip.upload.PickedMedia
import com.nelsul.curitibatrip.upload.UploadJob
import com.nelsul.curitibatrip.upload.Uploads
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Duration
import java.time.Instant

/** A picked item before it's sent. */
data class Draft(val media: PickedMedia, val caption: String = "", val loc: Loc = Loc.None) {
	/** where the post goes on the map: the photo's own GPS, where the phone is now, or nowhere */
	enum class Loc { Photo, Here, None }
}

/** Kept outside the screen so picked items survive switching tabs. */
object EnviarModel {
	val drafts = mutableStateListOf<Draft>()
	var here by mutableStateOf<Pair<Double, Double>?>(null)
	/** a row asked for "Onde estou agora" before the position was known */
	var wantsHere by mutableStateOf<String?>(null)

	/** Queues every picked item (the button under the list, or the top bar's "Enviar" while on this screen). */
	fun send() {
		val here = this.here
		for (d in drafts) {
			val m = d.media
			val useHere = d.loc == Draft.Loc.Here && here != null
			val usePhoto = d.loc == Draft.Loc.Photo && m.hasLocation
			Uploads.add(UploadJob(
				id = Uploads.newId(), sourceUri = m.sourceUri.toString(), assetId = m.assetId, caption = d.caption.trim(),
				name = m.name, mime = m.mime, size = m.size, isVideo = m.isVideo, takenAt = m.takenAt?.toString(),
				lat = if (useHere) here!!.first else if (usePhoto) m.lat else null, lng = if (useHere) here!!.second else if (usePhoto) m.lng else null,
				// over the photo's own GPS: "manual", so the server keeps this choice
				locationSource = if (useHere) (if (m.hasLocation) "manual" else "device") else if (usePhoto) "device-library" else null,
				wifiOnly = Uploads.wifiOnly.value,
			))
		}
		drafts.clear()
	}
}

/** Names for coordinates (GET /api/places/here), cached for the session. */
object PlaceNames {
	private val cache = androidx.compose.runtime.mutableStateMapOf<String, String>()
	private val asked = mutableSetOf<String>()
	private fun key(c: Pair<Double, Double>) = "%.4f,%.4f".format(java.util.Locale.US, c.first, c.second)
	fun name(c: Pair<Double, Double>?) = c?.let { cache[key(it)] }
	suspend fun load(c: Pair<Double, Double>) {
		val k = key(c)
		if (!asked.add(k)) return
		runCatching { com.nelsul.curitibatrip.data.Api.get<PlaceHere>("/api/places/here", mapOf("lat" to c.first.toString(), "lng" to c.second.toString())).name }
			.getOrNull()?.takeIf { it.isNotEmpty() }?.let { cache[k] = it }
	}
}

@kotlinx.serialization.Serializable
private data class PlaceHere(val name: String)

/** Use the phone's position only for things captured recently (same rule as the web and iOS). */
private val FRESH = Duration.ofHours(2)

private fun galleryPermissions(): Array<String> = when {
	Build.VERSION.SDK_INT >= 34 -> arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO, Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED, Manifest.permission.ACCESS_MEDIA_LOCATION)
	Build.VERSION.SDK_INT >= 33 -> arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO, Manifest.permission.ACCESS_MEDIA_LOCATION)
	Build.VERSION.SDK_INT >= 29 -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.ACCESS_MEDIA_LOCATION)
	else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
}

/** Full gallery access (not "Permitir acesso limitado"): picked items can be read as originals, with their GPS. */
private fun hasFullGallery(context: Context): Boolean {
	fun ok(p: String) = ContextCompat.checkSelfPermission(context, p) == PackageManager.PERMISSION_GRANTED
	return when {
		Build.VERSION.SDK_INT >= 33 -> ok(Manifest.permission.READ_MEDIA_IMAGES) && ok(Manifest.permission.READ_MEDIA_VIDEO)
		else -> ok(Manifest.permission.READ_EXTERNAL_STORAGE)
	}
}

/** Asked for gallery access once already: don't ask again on every pick (Android 14 would reopen its own photo chooser each time). */
private fun askedGallery(context: Context) = context.getSharedPreferences("enviar", Context.MODE_PRIVATE).getBoolean("asked-gallery", false)
private fun markAskedGallery(context: Context) = context.getSharedPreferences("enviar", Context.MODE_PRIVATE).edit().putBoolean("asked-gallery", true).apply()

/** Enviar (web /enviar): pick photos and videos, add captions, send the originals. Sending continues with the app closed. */
@Composable
fun EnviarScreen(contentPadding: PaddingValues, open: (Route) -> Unit) {
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	val jobs by Uploads.jobs.collectAsState()
	val sent by Uploads.sent.collectAsState()
	var message by remember { mutableStateOf<String?>(null) }
	var noOriginals by remember { mutableStateOf(false) }
	val drafts = EnviarModel.drafts

	val locationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { granted ->
		if (granted.values.any { it }) scope.launch {
			try {
				val l = LocationOnce.current(context)
				EnviarModel.here = l.latitude to l.longitude
				drafts.indices.forEach { i ->
					val d = drafts[i]
					if ((!d.media.hasLocation && d.media.fresh() && d.loc == Draft.Loc.None) || d.media.assetId == EnviarModel.wantsHere) drafts[i] = d.copy(loc = Draft.Loc.Here)
				}
				EnviarModel.wantsHere = null
			} catch (e: Exception) { message = e.message }
		}
	}

	fun added(items: List<PickedMedia>) {
		message = null
		noOriginals = items.any { it.sourceUri == it.pickerUri }
		for (m in items) if (drafts.none { it.media.assetId == m.assetId }) drafts += Draft(m, loc = when {
			m.hasLocation -> Draft.Loc.Photo
			EnviarModel.here != null && m.fresh() -> Draft.Loc.Here
			else -> Draft.Loc.None
		})
		if (EnviarModel.here == null && items.any { !it.hasLocation && it.fresh() }) {
			locationPermission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
		}
	}

	val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(50)) { uris ->
		if (uris.isNotEmpty()) scope.launch {
			val items = withContext(Dispatchers.IO) { uris.mapNotNull { runCatching { MediaReader.read(context, it) }.getOrNull() } }
			if (items.size < uris.size) message = "Alguns itens não puderam ser abertos."
			added(items)
		}
	}
	// the phone's camera: the photo/video goes to the gallery (Pictures/Movies › Curitiba), then into the list like a picked one
	var captureUri by rememberSaveable { mutableStateOf<Uri?>(null) }
	fun captured(ok: Boolean) {
		val uri = captureUri ?: return
		captureUri = null
		scope.launch {
			if (!ok) { withContext(Dispatchers.IO) { runCatching { context.contentResolver.delete(uri, null, null) } }; return@launch }
			val item = withContext(Dispatchers.IO) { runCatching { MediaReader.read(context, uri) }.getOrNull() }
			if (item == null) message = "Não foi possível abrir o que foi gravado." else added(listOf(item))
		}
	}
	val takePhoto = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { captured(it) }
	val takeVideo = rememberLauncherForActivityResult(ActivityResultContracts.CaptureVideo()) { captured(it) }
	fun capture(video: Boolean) {
		val uri = runCatching { newCaptureUri(context, video) }.getOrNull()
		if (uri == null) { message = "Não foi possível abrir a câmera."; return }
		captureUri = uri
		try { if (video) takeVideo.launch(uri) else takePhoto.launch(uri) } catch (e: Exception) { captureUri = null; message = "Nenhum app de câmera encontrado." }
	}
	fun openPicker() = picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo))
	// gallery access is asked once (so we can send the original with its location), then the picker either way;
	// with limited or no access the picker still works: those items go as the picker's copy
	val galleryPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
		markAskedGallery(context)
		openPicker()
	}
	fun pick() {
		if (hasFullGallery(context) || askedGallery(context)) openPicker() else galleryPermission.launch(galleryPermissions())
	}

	Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
		Column(Modifier.widthIn(max = 640.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
			TitleRow(IconName.Upload, "Enviar")
			Text("Fotos e vídeos vão no arquivo original, em qualidade total, com o local e a hora da própria foto. Pode fechar o app: o envio continua.",
				style = body(16), color = Palette.muted)
			PickerTile { pick() }
			Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
				ChunkyButton("Tirar foto", { capture(false) }, Modifier.weight(1f), variant = ButtonVariant.Secondary, fullWidth = true, icon = IconName.Camera)
				ChunkyButton("Gravar vídeo", { capture(true) }, Modifier.weight(1f), variant = ButtonVariant.Secondary, fullWidth = true, icon = IconName.Video)
			}
			// "Enviar só no Wi-Fi": the originals wait for Wi-Fi (a low-res preview goes to the diary right away)
			val wifiOnly by Uploads.wifiOnly.collectAsState()
			Row(Modifier.fillMaxWidth().card(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
				Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
					Text("Enviar só no Wi‑Fi", style = body(16, FontWeight.Bold), color = Palette.ink)
					Text("Fora do Wi‑Fi, vai para o diário uma prévia leve; o original sobe sozinho quando o celular entrar no Wi‑Fi. Dá para mandar um agora em “Enviar agora”.",
						style = body(13), color = Palette.muted)
				}
				androidx.compose.material3.Switch(wifiOnly, { Uploads.setWifiOnly(it) },
					colors = androidx.compose.material3.SwitchDefaults.colors(checkedTrackColor = Palette.leaf, checkedThumbColor = Color.White))
			}
			if (noOriginals) Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
				Text("O app não vê algumas dessas fotos na galeria (acesso limitado ou negado). Elas vão mesmo assim, mas sem o local da foto: escolha “Onde estou agora” ou marque depois no mapa.",
					style = body(15, FontWeight.Bold), color = Palette.ink)
				Text("Para mandar sempre o original com o local, permita acesso a todas as fotos e vídeos.", style = body(14), color = Palette.muted)
				ChunkyButton("Abrir configurações", {
					context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)))
				}, variant = ButtonVariant.Sea, small = true)
			}
			message?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }

			drafts.forEachIndexed { i, d ->
				DraftRow(d, EnviarModel.here, onChange = { drafts[i] = it }, onRemove = { drafts.removeAt(i) }, askHere = {
					EnviarModel.wantsHere = d.media.assetId
					locationPermission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
				})
			}
			if (drafts.isNotEmpty()) ChunkyButton("Enviar ${drafts.size} ${if (drafts.size == 1) "arquivo" else "arquivos"}", {
				EnviarModel.send()
			}, variant = ButtonVariant.Sun, fullWidth = true)

			if (jobs.isNotEmpty()) {
				Row(verticalAlignment = Alignment.CenterVertically) {
					Text(if (jobs.any { it.active }) "Enviando" else "Enviados", style = display(20), color = Palette.ink, modifier = Modifier.weight(1f))
					if (jobs.any { it.state == UploadJob.State.Done }) ChunkyButton("Limpar enviados", { Uploads.clearFinished() }, variant = ButtonVariant.Secondary, small = true)
				}
				jobs.reversed().forEach { job -> JobRow(job, sent[job.id], open) }
			}
		}
	}
}

private fun PickedMedia.fresh() = takenAt?.let { Duration.between(it, Instant.now()) < FRESH } ?: true

@Composable
private fun PickerTile(onClick: () -> Unit) {
	val wiggle by rememberInfiniteTransition(label = "wiggle").animateFloat(-10f, -2f, infiniteRepeatable(tween(1500), RepeatMode.Reverse), label = "w")
	Column(
		Modifier
			.fillMaxWidth()
			.pressable(onClick)
			.drawBehind {
				val r = CornerRadius(Radius.card.toPx())
				drawRoundRect(Palette.surface, cornerRadius = r)
				val w = 3.dp.toPx()
				drawRoundRect(Palette.sea, Offset(w / 2, w / 2), Size(size.width - w, size.height - w), CornerRadius(r.x - w / 2),
					style = Stroke(w, pathEffect = PathEffect.dashPathEffect(floatArrayOf(9.dp.toPx(), 6.dp.toPx()))))
			}
			.padding(vertical = 26.dp)
			.semantics(mergeDescendants = true) { contentDescription = "Escolher fotos e vídeos" },
		horizontalAlignment = Alignment.CenterHorizontally,
		verticalArrangement = Arrangement.spacedBy(6.dp),
	) {
		Box(
			Modifier.rotate(wiggle).size(64.dp).drawBehind {
				val r = CornerRadius(22.dp.toPx())
				drawRoundRect(Palette.seaDark, topLeft = Offset(0f, 4.dp.toPx()), size = size, cornerRadius = r)
				drawRoundRect(Palette.sea, cornerRadius = r)
			},
			contentAlignment = Alignment.Center,
		) { Icon(IconName.Camera, Color.White, size = 34.dp) }
		Text("Escolher fotos e vídeos", style = display(19), color = Palette.ink)
		Text("Pode escolher vários de uma vez", style = body(14), color = Palette.muted)
	}
}

@Composable
private fun Thumb(uri: Any?, isVideo: Boolean) {
	Box(
		Modifier.rotate(-2f).shadow(4.dp, RoundedCornerShape(6.dp)).background(Palette.polaroid, RoundedCornerShape(6.dp)).padding(4.dp),
	) {
		Box(Modifier.size(80.dp).clip(RoundedCornerShape(4.dp)).background(Palette.track), contentAlignment = Alignment.Center) {
			AsyncImage(uri, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
			if (isVideo) Icon(IconName.Play, Color.White, size = 18.dp)
		}
	}
}

@Composable
private fun DraftRow(d: Draft, here: Pair<Double, Double>?, onChange: (Draft) -> Unit, onRemove: () -> Unit, askHere: () -> Unit) {
	val m = d.media
	Row(Modifier.popIn().fillMaxWidth().card(12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
		Thumb(m.pickerUri, m.isVideo)
		Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
			Row(verticalAlignment = Alignment.CenterVertically) {
				Text(if (m.isVideo) "Vídeo" else "Foto", style = body(16, FontWeight.Bold), color = Palette.ink)
				m.takenAt?.let { Text("  ${TripTime.time(it.toString())} · ${TripTime.dayKey(it.toString()).takeLast(5).split("-").reversed().joinToString("/")}", style = body(13), color = Palette.muted) }
				Spacer(Modifier.weight(1f))
				Text("×", style = body(26), color = Palette.muted, modifier = Modifier.pressable(onRemove).padding(horizontal = 6.dp).semantics { contentDescription = "Remover" })
			}
			LocationChoice(d, here, onChange, askHere)
			AppTextField(d.caption, { onChange(d.copy(caption = it)) }, "Comentário (opcional)", Modifier.fillMaxWidth())
		}
	}
}

@Composable
private fun JobRow(job: UploadJob, inFlight: Long?, open: (Route) -> Unit) {
	val context = LocalContext.current
	val sent = when (job.state) {
		UploadJob.State.Done, UploadJob.State.Finishing -> job.size
		else -> inFlight ?: (job.etags.size * job.partSize).coerceAtMost(job.size)
	}
	val pct = if (job.size > 0) sent.toFloat() / job.size else 0f
	Row(Modifier.fillMaxWidth().card(12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
		Thumb(job.sourceUri.let(Uri::parse), job.isVideo)
		Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
			Row(verticalAlignment = Alignment.CenterVertically) {
				Text(job.name, style = body(16, FontWeight.Bold), color = Palette.ink, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
				if (job.state != UploadJob.State.Done) Text("×", style = body(26), color = Palette.muted,
					modifier = Modifier.pressable({ Uploads.cancel(job.id) }).padding(horizontal = 6.dp).semantics { contentDescription = "Cancelar envio" })
			}
			Text(Formatter.formatShortFileSize(context, job.size) + if (job.lat != null) " · com local" else " · sem local", style = body(13), color = Palette.muted)
			if (job.caption.isNotEmpty()) Text("“${job.caption}”", style = body(14), color = Palette.ink, maxLines = 2)
			if (job.state != UploadJob.State.Waiting) UploadFlight(pct, done = job.state == UploadJob.State.Done, failed = job.state == UploadJob.State.Failed)
			val waitingWifi = job.wifiOnly && job.previewSent && inFlight == null &&
				(job.state == UploadJob.State.Waiting || job.state == UploadJob.State.Uploading)
			if (waitingWifi) Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
					Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
						Icon(IconName.Clock, Palette.sky, size = 14.dp)
						Text("Esperando Wi‑Fi · a prévia já está no diário", style = body(13, FontWeight.Bold), color = Palette.sky)
					}
					ChunkyButton("Enviar agora", { Uploads.sendNow(job.id) }, variant = ButtonVariant.Secondary, small = true)
			} else when (job.state) {
				UploadJob.State.Waiting -> Text("Na fila (espera internet)", style = body(13), color = Palette.muted)
				UploadJob.State.Uploading -> Text("Voando… ${(pct * 100).toInt()}%", style = body(13), color = Palette.muted)
				UploadJob.State.Finishing -> Text("Pousando…", style = body(13), color = Palette.muted)
				UploadJob.State.Done -> job.mediaId?.let { id ->
					TextLink(if (job.duplicate) "Já estava no diário · ver" else "Ver no diário", { open(Route.Media(id)) }, color = Palette.sea)
				}
				UploadJob.State.Failed -> Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
					Text(job.error ?: "Falhou.", style = body(13, FontWeight.Bold), color = Palette.danger)
					ChunkyButton("Tentar de novo", { Uploads.retry(job.id) }, variant = ButtonVariant.Sea, small = true)
				}
			}
		}
	}
}

/** A new, empty gallery entry for the camera app to write into (Pictures/Curitiba or Movies/Curitiba). */
private fun newCaptureUri(context: android.content.Context, video: Boolean): Uri? {
	val stamp = java.time.LocalDateTime.now().format(java.time.format.DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"))
	val values = android.content.ContentValues().apply {
		put(MediaStore.MediaColumns.DISPLAY_NAME, "curitiba_$stamp.${if (video) "mp4" else "jpg"}")
		put(MediaStore.MediaColumns.MIME_TYPE, if (video) "video/mp4" else "image/jpeg")
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) put(MediaStore.MediaColumns.RELATIVE_PATH, if (video) "Movies/Curitiba" else "Pictures/Curitiba")
	}
	val base = if (video) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
	return context.contentResolver.insert(base, values)
}

/**
 * Where a post goes on the map, chosen before sending: "Onde a foto foi tirada" (its own GPS), "Onde estou agora"
 * (the phone's position) or "Sem local", with the place's name, so a photo taken earlier isn't pinned by mistake.
 */
@Composable
private fun LocationChoice(d: Draft, here: Pair<Double, Double>?, onChange: (Draft) -> Unit, askHere: () -> Unit) {
	val m = d.media
	val photo = if (m.hasLocation && m.lat != null && m.lng != null) m.lat to m.lng else null
	val shown = if (d.loc == Draft.Loc.Photo) photo else if (d.loc == Draft.Loc.Here) here else null
	androidx.compose.runtime.LaunchedEffect(shown) { shown?.let { PlaceNames.load(it) } }
	Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
		Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
			@Composable
			fun option(value: Draft.Loc, icon: IconName?, label: String) {
				val on = d.loc == value
				Row(
					Modifier.heightIn(min = 32.dp).background(if (on) Palette.leaf else Palette.surface2, CircleShape)
						.border(2.dp, if (on) Palette.leaf else Palette.line, CircleShape)
						.pressable({ if (value == Draft.Loc.Here && here == null) askHere() else onChange(d.copy(loc = value)) })
						.padding(horizontal = 10.dp).semantics { selected = on },
					verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp),
				) {
					if (icon != null) Icon(icon, if (on) Palette.onLeaf else Palette.ink, size = 14.dp)
					Text(label, style = body(13, FontWeight.ExtraBold), color = if (on) Palette.onLeaf else Palette.ink)
				}
			}
			if (photo != null) option(Draft.Loc.Photo, IconName.Camera, "Onde a foto foi tirada")
			option(Draft.Loc.Here, IconName.Locate, "Onde estou agora")
			if (photo == null) option(Draft.Loc.None, null, "Sem local")
		}
		val old = m.takenAt?.let { Duration.between(it, Instant.now()) > FRESH } ?: false
		when {
			d.loc == Draft.Loc.Photo && photo != null -> PlaceLine(PlaceNames.name(photo) ?: "Local da foto", "gravado na própria foto")
			d.loc == Draft.Loc.Here && here != null -> {
				PlaceLine(PlaceNames.name(here) ?: "Sua localização", "onde você está agora")
				if (old) m.takenAt?.let {
					Text("A foto é de ${TripTime.dayKey(it.toString()).takeLast(5).split("-").reversed().joinToString("/")} ${TripTime.time(it.toString())}: confira se foi tirada aqui.",
						style = body(13, FontWeight.Bold), color = Palette.sun)
				}
			}
			else -> Text(if (m.isVideo) "Sem local (se o vídeo tiver, ele é usado)" else "Sem local — dá para marcar depois, no mapa", style = body(13), color = Palette.muted)
		}
	}
}

@Composable
private fun PlaceLine(place: String, how: String) {
	Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
		Icon(IconName.Pin, Palette.leaf, size = 14.dp)
		Text(androidx.compose.ui.text.buildAnnotatedString {
			withStyle(androidx.compose.ui.text.SpanStyle(fontWeight = FontWeight.ExtraBold, color = Palette.leaf)) { append(place) }
			withStyle(androidx.compose.ui.text.SpanStyle(color = Palette.muted)) { append(" · $how") }
		}, style = body(13))
	}
}
