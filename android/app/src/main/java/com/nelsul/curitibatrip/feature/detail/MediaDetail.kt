package com.nelsul.curitibatrip.feature.detail

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.text.format.Formatter
import android.widget.MediaController
import android.widget.VideoView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.Gallery
import com.nelsul.curitibatrip.data.LikeBody
import com.nelsul.curitibatrip.data.LatLngBody
import com.nelsul.curitibatrip.feature.mapa.LocationPicker
import org.maplibre.android.geometry.LatLng
import com.nelsul.curitibatrip.data.LikeResponse
import com.nelsul.curitibatrip.data.MediaDetail
import com.nelsul.curitibatrip.data.MediaItem
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.feature.feed.EmptyState
import com.nelsul.curitibatrip.feature.feed.LikeButton
import com.nelsul.curitibatrip.feature.feed.LikedBy
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.BackButton
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.ConfirmDialog
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TextEditDialog
import com.nelsul.curitibatrip.ui.components.TextLink
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.components.pointerInputTap
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import com.nelsul.curitibatrip.ui.theme.popIn
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Photo/video page (web /m/:id): polaroid viewer, likes, caption, location, file, save original, delete, comments. */
@Composable
fun MediaDetailScreen(id: String, contentPadding: PaddingValues, onBack: () -> Unit) {
	val app = LocalApp.current
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	var detail by remember { mutableStateOf<MediaDetail?>(null) }
	var error by remember { mutableStateOf<String?>(null) }
	var editing by remember { mutableStateOf(false) }
	var confirmDelete by remember { mutableStateOf(false) }
	var zoom by remember { mutableStateOf(false) }
	var saving by remember { mutableStateOf<String?>(null) }
	var placing by remember { mutableStateOf(false) }

	suspend fun load() {
		try { detail = Api.get("/api/media/$id"); error = null } catch (e: Exception) { app.handle(e); error = e.message }
	}
	LaunchedEffect(id) { load() }

	fun save(item: MediaItem) = scope.launch {
		val url = item.original ?: return@launch
		saving = "Baixando…"
		try {
			Gallery.saveOriginal(context, url, item.originalName.ifEmpty { "viagem-${item.id}" }, item.isVideo)
			saving = "Salvo na galeria ✓"
			delay(3000)
		} catch (e: Exception) {
			error = "Não foi possível salvar: ${e.message}"
		} finally { saving = null }
	}
	var pendingSave by remember { mutableStateOf<MediaItem?>(null) }
	val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
		val item = pendingSave
		pendingSave = null
		if (ok && item != null) save(item) else error = "Sem permissão para salvar na galeria."
	}

	Column(
		Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding).padding(16.dp),
		horizontalAlignment = Alignment.CenterHorizontally,
	) {
		Column(Modifier.widthIn(max = 640.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
			BackButton(onBack)
			val d = detail
			when {
				d != null -> {
					val item = d.item
					val person = app.person(item.userId)
					val mine = item.userId == app.me?.id
					Viewer(item) { zoom = true }
					Row(verticalAlignment = Alignment.CenterVertically) {
						LikeButton(d.likers.contains(app.me?.id)) { liked ->
							scope.launch {
								val me = app.me?.id ?: return@launch
								val before = d.likers
								detail = d.copy(likers = if (liked) before + me else before - me)
								try {
									val r: LikeResponse = Api.post("/api/likes", LikeBody(mediaId = id, liked = liked))
									detail = detail?.copy(likers = r.likers)
									app.feedChanged()
								} catch (e: Exception) { detail = detail?.copy(likers = before); app.handle(e) }
							}
						}
						LikedBy(d.likers)
					}
					Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
						Avatar(person?.name ?: "?", person?.let { colorOf(it.color) } ?: Palette.muted, person?.photo, 44.dp)
						Column {
							Text(person?.name ?: "Alguém", style = display(19), color = Palette.ink)
							Text("${TripTime.longDay(TripTime.dayKey(item.at))}, ${TripTime.time(item.at)}${if (item.takenAtSource == "upload") " (hora do envio)" else ""}",
								style = body(14), color = Palette.muted)
						}
					}
					if (item.caption.isNotEmpty()) {
						Text(item.caption, style = body(17), color = Palette.ink, modifier = Modifier.fillMaxWidth().card(padding = 0.dp, radius = 18.dp).padding(horizontal = 14.dp, vertical = 10.dp))
					}
					if (mine) TextLink(if (item.caption.isEmpty()) "Adicionar texto" else "Editar texto", { editing = true })
					if (item.lat != null && item.lng != null) {
						Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
							Icon(IconName.Pin, Palette.sea, size = 18.dp)
							Text(locationLabel(item.locationSource), style = body(14), color = Palette.muted, modifier = Modifier.weight(1f))
							if (mine) TextLink("Corrigir", { placing = true })
							TextLink("Google Maps", { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/maps/search/?api=1&query=${item.lat},${item.lng}"))) })
						}
					}
					else if (mine) ChunkyButton("Marcar no mapa", { placing = true }, variant = ButtonVariant.Secondary, small = true, icon = IconName.Pin)
					Text(fileLine(context, item), style = body(13), color = Palette.muted)
					Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
						ChunkyButton(saving ?: "Salvar original na galeria", {
							if (Gallery.needsPermission && context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
								pendingSave = item
								permission.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
							} else save(item)
						}, variant = ButtonVariant.Sea, small = true, enabled = saving == null && item.original != null, icon = IconName.Download)
						if (mine) ChunkyButton("Apagar", { confirmDelete = true }, variant = ButtonVariant.Danger, small = true)
					}
					error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }
					CommentsSection("/api/media/$id/comments", d.comments) { detail = detail?.copy(comments = it) }

					if (editing) TextEditDialog("Texto da foto", item.caption, { editing = false }) { text ->
						val updated: MediaItem = Api.patch("/api/media/$id", mapOf("caption" to text))
						detail = detail?.copy(item = updated)
						app.feedChanged()
					}
					if (confirmDelete) ConfirmDialog("Apagar este arquivo para todo mundo? Não dá para desfazer.", "Apagar", { confirmDelete = false }) {
						scope.launch {
							try { Api.delete("/api/media/$id"); app.feedChanged(); onBack() } catch (e: Exception) { app.handle(e); error = e.message }
						}
					}
					if (zoom) ZoomViewer(item.display ?: item.medium) { zoom = false }
					if (placing) LocationPicker(if (item.lat != null && item.lng != null) LatLng(item.lat, item.lng) else null, { placing = false }) { c ->
						val updated: MediaItem = Api.patch("/api/media/$id", LatLngBody(c.latitude, c.longitude))
						detail = detail?.copy(item = updated)
						app.feedChanged()
					}
				}
				error != null -> EmptyState(error!!, retry = { scope.launch { load() } })
				else -> Box(Modifier.fillMaxWidth().padding(top = 80.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Palette.sea) }
			}
		}
	}
}

/** The photo or video in a white polaroid frame. */
@Composable
private fun Viewer(item: MediaItem, onZoom: () -> Unit) {
	val ratio = if (item.width != null && item.height != null && item.height > 0) item.width.toFloat() / item.height else 1f
	Box(
		Modifier
			.popIn()
			.rotate(-0.6f)
			.shadow(10.dp, RoundedCornerShape(8.dp))
			.background(Palette.polaroid, RoundedCornerShape(8.dp))
			.padding(start = 8.dp, top = 8.dp, end = 8.dp, bottom = 22.dp),
	) {
		val inner = Modifier.fillMaxWidth().clip(RoundedCornerShape(4.dp))
		when {
			item.status != "ready" -> Box(inner.heightIn(min = 220.dp).background(Color.Black), contentAlignment = Alignment.Center) {
				if (item.poster != null) AsyncImage(item.poster, null, Modifier.fillMaxWidth().graphicsLayer { alpha = 0.5f }, contentScale = ContentScale.Fit)
				Text(
					when { item.status == "failed" -> "Não foi possível processar este arquivo. O original está salvo e pode ser baixado."; item.isVideo -> "Processando o vídeo (alguns minutos)…"; else -> "Processando…" },
					style = body(15, FontWeight.Bold), color = Color.White, textAlign = TextAlign.Center, modifier = Modifier.padding(16.dp),
				)
			}
			item.isVideo && item.video != null -> AndroidView(
				factory = { ctx ->
					VideoView(ctx).apply {
						setMediaController(MediaController(ctx).also { it.setAnchorView(this) })
						setVideoURI(Uri.parse(item.video))
						setOnPreparedListener { start() }
					}
				},
				modifier = inner.aspectRatio(ratio),
				onRelease = { it.stopPlayback() },
			)
			else -> AsyncImage(
				item.display ?: item.medium, item.caption.ifEmpty { "Foto. Toque para ampliar" }, contentScale = ContentScale.Fit,
				modifier = inner.aspectRatio(ratio).background(Palette.track).let { m -> m.then(Modifier.semantics { contentDescription = "Ampliar" }) }
					.pointerInputTap(onZoom),
			)
		}
	}
}

/** Full-screen photo with pinch to zoom and drag; tap the background to close. */
@Composable
private fun ZoomViewer(url: String?, onClose: () -> Unit) {
	var scale by remember { mutableFloatStateOf(1f) }
	var offset by remember { mutableStateOf(Offset.Zero) }
	val state = rememberTransformableState { zoom, pan, _ ->
		scale = (scale * zoom).coerceIn(1f, 6f)
		offset = if (scale > 1f) offset + pan else Offset.Zero
	}
	Dialog(onClose, DialogProperties(usePlatformDefaultWidth = false)) {
		Box(Modifier.fillMaxSize().background(Color.Black).pointerInputTap(onClose), contentAlignment = Alignment.Center) {
			AsyncImage(url, "Foto ampliada", contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize().transformable(state).graphicsLayer {
				scaleX = scale; scaleY = scale; translationX = offset.x; translationY = offset.y
			})
			Spacer(Modifier)
		}
	}
}

private fun locationLabel(source: String?) = when (source) {
	"exif" -> "Local da própria foto"
	"device", "device-library" -> "Local do celular"
	"manual" -> "Local marcado à mão"
	else -> "Local"
}

private fun fileLine(context: android.content.Context, i: MediaItem): String {
	val parts = mutableListOf(i.originalName, Formatter.formatShortFileSize(context, i.sizeBytes))
	if (i.width != null && i.height != null) parts += "${i.width}×${i.height}"
	i.durationS?.let { parts += "%d:%02d".format(it.toInt() / 60, it.toInt() % 60) }
	return parts.joined()
}

private fun List<String>.joined() = filter { it.isNotEmpty() }.joinToString(" · ")
