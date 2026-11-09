package com.nelsul.curitibatrip.feature.retro

import android.net.Uri
import android.widget.VideoView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.FeedMedia
import com.nelsul.curitibatrip.data.Ok
import com.nelsul.curitibatrip.data.Retro
import com.nelsul.curitibatrip.data.RetroBody
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.data.Wedding
import com.nelsul.curitibatrip.feature.feed.CountdownCard
import com.nelsul.curitibatrip.feature.feed.EmptyState
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.BackButton
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TitleRow
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * Retrospectiva: the wedding countdown, then the admin's picks played like stories (a year-in-review).
 * Admins pick photos/videos in the Diário's grid ("Retrô") and put them in order here.
 */
@Composable
fun RetroScreen(contentPadding: PaddingValues, back: () -> Unit) {
	val app = LocalApp.current
	val scope = rememberCoroutineScope()
	var retro by remember { mutableStateOf<Retro?>(null) }
	var error by remember { mutableStateOf<String?>(null) }
	var playing by remember { mutableStateOf(false) }
	var ordering by remember { mutableStateOf(false) }
	val order = remember { mutableStateListOf<FeedMedia>() }
	suspend fun load() { try { retro = Api.get("/api/retro"); error = null } catch (e: Exception) { app.handle(e); error = e.message } }
	LaunchedEffect(Unit) { load() }
	val started = !Instant.now().isBefore(Wedding.at)
	val items = retro?.items ?: emptyList()

	Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
		Column(Modifier.widthIn(max = 640.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
			BackButton(back)
			TitleRow(IconName.Sparkle, "Retrospectiva")
			if (!started) {
				CountdownCard({}, big = true)
				Text("Depois do casamento, aqui aparecem os melhores momentos da viagem, escolhidos a dedo, um atrás do outro.", style = body(16), color = Palette.muted)
			} else if (items.isNotEmpty()) {
				Box(
					Modifier.fillMaxWidth().aspectRatio(4f / 5f).clip(RoundedCornerShape(22.dp)).border(2.5.dp, Palette.sun, RoundedCornerShape(22.dp))
						.pressable({ playing = true }).semantics { contentDescription = "Ver a retrospectiva" },
					contentAlignment = Alignment.Center,
				) {
					AsyncImage(items[0].image, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
					Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f)))
					Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
						Box(Modifier.size(76.dp).background(Palette.sun, CircleShape), contentAlignment = Alignment.Center) { Icon(IconName.Play, Palette.onSun, size = 34.dp) }
						Text("Ver a retrospectiva", style = display(26), color = Color.White)
						Text("${items.size} momentos", style = body(15), color = Color.White)
					}
				}
			} else if (retro != null) EmptyState("A retrospectiva está sendo preparada. Volte daqui a pouco!")
			error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }

			if (app.me?.isAdmin == true && retro != null) Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
				Text("Só para administradores", style = display(19), color = Palette.ink)
				if (!ordering) {
					Text("${items.size} ${if (items.size == 1) "item escolhido" else "itens escolhidos"}. Para pôr fotos, use “Todas as fotos” no Diário, Selecionar e “Retrô”.",
						style = body(14), color = Palette.muted)
					if (items.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
						ChunkyButton("Ordenar", { order.clear(); order.addAll(items); ordering = true }, variant = ButtonVariant.Sun, small = true)
						ChunkyButton("Pré-visualizar", { playing = true }, variant = ButtonVariant.Secondary, small = true)
					}
				} else {
					order.forEachIndexed { i, m ->
						Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
							Text("${i + 1}", style = body(14, FontWeight.ExtraBold), color = Palette.sun, modifier = Modifier.widthIn(min = 22.dp))
							AsyncImage(m.thumb ?: m.image, null, contentScale = ContentScale.Crop, modifier = Modifier.size(44.dp).clip(RoundedCornerShape(8.dp)))
							Text(m.caption.ifEmpty { if (m.isVideo) "Vídeo" else "Foto" } + " · " + (app.person(m.userId)?.name ?: ""),
								style = body(14), color = Palette.ink, maxLines = 1, modifier = Modifier.weight(1f))
							Small(IconName.Up, "Subir", i > 0) { order.add(i - 1, order.removeAt(i)) }
							Small(IconName.Down, "Descer", i < order.size - 1) { order.add(i + 1, order.removeAt(i)) }
							Small(IconName.Close, "Tirar", true) { order.removeAt(i) }
						}
					}
					Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
						ChunkyButton("Cancelar", { ordering = false }, variant = ButtonVariant.Secondary, small = true)
						ChunkyButton("Salvar", {
							scope.launch {
								try { Api.putJson<RetroBody, Ok>("/api/admin/retro", RetroBody(order.map { it.id })); ordering = false; load() }
								catch (e: Exception) { app.handle(e); error = e.message }
							}
						}, variant = ButtonVariant.Sun, small = true)
					}
				}
			}
		}
	}
	if (playing) StoryDialog(items) { playing = false }
}

@Composable
private fun Small(icon: IconName, label: String, enabled: Boolean, onClick: () -> Unit) {
	Box(
		Modifier.size(40.dp).background(Palette.surface2, RoundedCornerShape(12.dp)).border(2.dp, Palette.line, RoundedCornerShape(12.dp))
			.pressable(onClick, enabled).semantics { contentDescription = label },
		contentAlignment = Alignment.Center,
	) { Icon(icon, if (enabled) Palette.ink else Palette.muted.copy(alpha = 0.35f), size = 18.dp) }
}

/** The Retrospectiva as stories: an opening card, the picks in order, a closing card. Tap right/left, hold to pause. */
@Composable
fun StoryDialog(items: List<FeedMedia>, onClose: () -> Unit) {
	val app = LocalApp.current
	val total = items.size + 2
	var index by remember { mutableIntStateOf(0) }
	var progress by remember { mutableFloatStateOf(0f) }
	var paused by remember { mutableStateOf(false) }
	var videoView by remember { mutableStateOf<VideoView?>(null) }
	val current = items.getOrNull(index - 1)
	fun go(n: Int) { if (n >= total) onClose() else { index = n.coerceAtLeast(0); progress = 0f } }
	LaunchedEffect(index) {
		var last = 0L
		while (true) {
			val t = withFrameMillis { it }
			val dt = if (last == 0L) 0L else t - last
			last = t
			if (paused) continue
			val v = videoView
			if (current?.isVideo == true && v != null && v.duration > 0) {
				progress = v.currentPosition.toFloat() / v.duration
				if (!v.isPlaying && progress > 0.98f) { go(index + 1); break }
			} else if (current?.isVideo != true) {
				progress += dt / 5000f
				if (progress >= 1f) { go(index + 1); break }
			}
		}
	}
	Dialog(onClose, DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
		Box(
			Modifier.fillMaxSize().background(Color.Black).pointerInput(Unit) {
				awaitEachGesture {
					val down = awaitFirstDown()
					paused = true
					videoView?.pause()
					val up = waitForUpOrCancellation()
					paused = false
					videoView?.start()
					if (up != null && up.uptimeMillis - down.uptimeMillis < 300) go(if (up.position.x < size.width / 3f) index - 1 else index + 1)
				}
			},
		) {
			when {
				index == 0 -> Slide(Brush.radialGradient(listOf(Palette.berry, Palette.bg))) {
					Icon(IconName.Sparkle, Palette.sun, size = 64.dp)
					Text("RETROSPECTIVA", style = body(15, FontWeight.ExtraBold).copy(letterSpacing = 3.sp), color = Palette.sun)
					Text("Curitiba\n2026", style = display(58), color = Color.White, textAlign = TextAlign.Center)
					val days = items.map { it.day }.distinct().size
					val people = items.map { it.userId }.distinct().size
					Text("${items.size} momentos · $days ${if (days == 1) "dia" else "dias"} · $people ${if (people == 1) "pessoa" else "pessoas"}", style = body(17, FontWeight.Bold), color = Color.White)
				}
				current != null -> Box(Modifier.fillMaxSize()) {
					if (current.isVideo && current.video != null) AndroidView(
						factory = { ctx -> VideoView(ctx).apply { setVideoURI(Uri.parse(current.video)); setOnPreparedListener { start() }; videoView = this } },
						onRelease = { it.stopPlayback(); videoView = null },
						modifier = Modifier.fillMaxSize().systemBarsPadding(),
					) else AsyncImage(current.image, current.caption.ifEmpty { null }, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize())
					val p = app.person(current.userId)
					Column(
						Modifier.align(Alignment.BottomStart).fillMaxWidth().background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.7f))))
							.systemBarsPadding().padding(18.dp),
						verticalArrangement = Arrangement.spacedBy(4.dp),
					) {
						Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
							Avatar(p?.name ?: "?", colorOf(p?.color), p?.photo, 32.dp)
							Text(p?.name ?: "Alguém", style = display(18), color = Color.White)
						}
						Text(TripTime.longDay(current.day), style = body(14), color = Color.White)
						if (current.caption.isNotEmpty()) Text(current.caption, style = body(16), color = Color.White)
					}
				}
				else -> Slide(Brush.radialGradient(listOf(Palette.sunDark, Palette.bg))) {
					Icon(IconName.Heart, Palette.berry, size = 64.dp)
					Text("Obrigado por\nessa viagem!", style = display(46), color = Color.White, textAlign = TextAlign.Center)
					Text("Com amor, de Curitiba.", style = body(17), color = Color.White)
				}
			}
			Column(Modifier.systemBarsPadding().padding(horizontal = 10.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
				Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
					repeat(total) { n ->
						Box(Modifier.weight(1f).height(3.dp).background(Color.White.copy(alpha = 0.35f), CircleShape)) {
							Box(Modifier.fillMaxWidth(if (n < index) 1f else if (n == index) progress.coerceIn(0f, 1f) else 0f).height(3.dp).background(Color.White, CircleShape))
						}
					}
				}
				Box(Modifier.align(Alignment.End).size(44.dp).background(Color.Black.copy(alpha = 0.35f), CircleShape).pressable(onClose).semantics { contentDescription = "Fechar" },
					contentAlignment = Alignment.Center) { Icon(IconName.Close, Color.White, size = 20.dp) }
			}
		}
	}
}

@Composable
private fun Slide(bg: Brush, content: @Composable () -> Unit) {
	Column(Modifier.fillMaxSize().background(bg).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally,
		verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) { content() }
}
