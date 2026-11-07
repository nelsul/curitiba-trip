package com.nelsul.curitibatrip.feature.enviar

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
data class Draft(val media: PickedMedia, val caption: String = "", val useHere: Boolean = false)

/** Kept outside the screen so picked items survive switching tabs. */
object EnviarModel {
	val drafts = mutableStateListOf<Draft>()
	var here by mutableStateOf<Pair<Double, Double>?>(null)
}

/** Use the phone's position only for things captured recently (same rule as the web and iOS). */
private val FRESH = Duration.ofHours(2)

private fun galleryPermissions(): Array<String> = when {
	Build.VERSION.SDK_INT >= 34 -> arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO, Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED, Manifest.permission.ACCESS_MEDIA_LOCATION)
	Build.VERSION.SDK_INT >= 33 -> arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO, Manifest.permission.ACCESS_MEDIA_LOCATION)
	Build.VERSION.SDK_INT >= 29 -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.ACCESS_MEDIA_LOCATION)
	else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
}

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
				drafts.indices.forEach { i -> val d = drafts[i]; if (!d.media.hasLocation && d.media.fresh()) drafts[i] = d.copy(useHere = true) }
			} catch (e: Exception) { message = e.message }
		}
	}

	fun added(items: List<PickedMedia>) {
		message = null
		noOriginals = items.any { it.sourceUri == it.pickerUri }
		for (m in items) if (drafts.none { it.media.assetId == m.assetId }) drafts += Draft(m, useHere = EnviarModel.here != null && !m.hasLocation && m.fresh())
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
	// gallery access first (so we can send the original with its location), then the picker either way
	val galleryPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
		picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo))
	}

	Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
		Column(Modifier.widthIn(max = 640.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
			TitleRow(IconName.Upload, "Enviar")
			Text("Fotos e vídeos vão no arquivo original, em qualidade total, com o local e a hora da própria foto. Pode fechar o app: o envio continua.",
				style = body(16), color = Palette.muted)
			PickerTile { galleryPermission.launch(galleryPermissions()) }
			if (noOriginals) Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
				Text("Sem acesso às fotos: o local da foto não vem junto. Para enviar o original com o local, permita o acesso a fotos e vídeos.",
					style = body(15, FontWeight.Bold), color = Palette.ink)
				ChunkyButton("Abrir configurações", {
					context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)))
				}, variant = ButtonVariant.Sea, small = true)
			}
			message?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }

			drafts.forEachIndexed { i, d ->
				DraftRow(d, EnviarModel.here != null, onChange = { drafts[i] = it }, onRemove = { drafts.removeAt(i) })
			}
			if (drafts.isNotEmpty()) ChunkyButton("Enviar ${drafts.size} ${if (drafts.size == 1) "arquivo" else "arquivos"}", {
				val here = EnviarModel.here
				for (d in drafts) {
					val m = d.media
					val useHere = !m.hasLocation && d.useHere && here != null
					Uploads.add(UploadJob(
						id = Uploads.newId(), sourceUri = m.sourceUri.toString(), assetId = m.assetId, caption = d.caption.trim(),
						name = m.name, mime = m.mime, size = m.size, isVideo = m.isVideo, takenAt = m.takenAt?.toString(),
						lat = if (useHere) here!!.first else m.lat, lng = if (useHere) here!!.second else m.lng,
						locationSource = if (m.hasLocation) "device-library" else if (useHere) "device" else null,
					))
				}
				drafts.clear()
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
private fun DraftRow(d: Draft, hereAvailable: Boolean, onChange: (Draft) -> Unit, onRemove: () -> Unit) {
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
			when {
				m.hasLocation -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
					Icon(IconName.Pin, Palette.leaf, size = 15.dp)
					Text("Local da foto", style = body(14, FontWeight.ExtraBold), color = Palette.leaf)
				}
				hereAvailable -> Row(verticalAlignment = Alignment.CenterVertically) {
					Text("Usar minha localização atual", style = body(14), color = Palette.ink, modifier = Modifier.weight(1f))
					Switch(d.useHere, { onChange(d.copy(useHere = it)) }, colors = SwitchDefaults.colors(checkedTrackColor = Palette.leaf, checkedThumbColor = Color.White))
				}
				else -> Text("Sem local — dá para marcar depois", style = body(14), color = Palette.muted)
			}
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
			when (job.state) {
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
