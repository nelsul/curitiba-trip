package com.nelsul.curitibatrip.feature.galeria

import androidx.compose.foundation.border
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import android.media.MediaPlayer
import android.widget.VideoView
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.compose.LifecycleResumeEffect
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.feature.feed.pinchToZoom
import com.nelsul.curitibatrip.AppState
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.FeedMedia
import com.nelsul.curitibatrip.data.LikeBody
import com.nelsul.curitibatrip.data.LikeResponse
import com.nelsul.curitibatrip.data.Person
import com.nelsul.curitibatrip.data.Route
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.feature.feed.BigHeart
import com.nelsul.curitibatrip.feature.feed.EmptyState
import com.nelsul.curitibatrip.feature.feed.LikeButton
import com.nelsul.curitibatrip.feature.feed.Opener
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import kotlinx.coroutines.launch
import java.time.format.DateTimeFormatter

/**
 * Every photo and video (no check-ins), newest first: the Diário's grid ("Todas as fotos") and the reels.
 * Loads every page of GET /api/feed (a trip has a few hundred items at most).
 */
class MediaLibrary {
	var items by mutableStateOf<List<FeedMedia>>(emptyList())
		private set
	var loading by mutableStateOf(false)
		private set
	var error by mutableStateOf<String?>(null)
		private set

	suspend fun refresh(app: AppState) {
		if (loading) return
		loading = true
		try {
			// one request: only ready ones, newest first
			items = Api.get<GridPage>("/api/feed/media").media
			error = null
		} catch (e: Exception) {
			app.handle(e)
			error = e.message
		} finally {
			loading = false
		}
	}

	fun filtered(day: String?, person: String?) = items.filter { (day == null || it.day == day) && (person == null || it.userId == person) }
}

@kotlinx.serialization.Serializable
private data class GridPage(val media: List<FeedMedia>)

private val dateTime = DateTimeFormatter.ofPattern("dd/MM, HH:mm", TripTime.locale).withZone(TripTime.zone)

/**
 * Full-screen reels over the Diário (like Instagram), starting at the photo/video that was tapped. Only the page on
 * screen plays, and nothing plays while the app is in the background.
 */
@Composable
fun ReelsOverlay(items: List<FeedMedia>, start: String, onClose: () -> Unit, open: Opener, onShare: (FeedMedia) -> Unit) {
	val app = LocalApp.current
	val scope = rememberCoroutineScope()
	var gone by remember { mutableStateOf(setOf<String>()) }
	val shown = items.filter { it.id !in gone }
	val pager = rememberPagerState(initialPage = items.indexOfFirst { it.id == start }.coerceAtLeast(0)) { shown.size }
	var resumed by remember { mutableStateOf(true) }
	var muted by remember { mutableStateOf(false) }
	var deleting by remember { mutableStateOf<FeedMedia?>(null) }
	LifecycleResumeEffect(Unit) {
		resumed = true
		onPauseOrDispose { resumed = false }
	}
	Dialog(onClose, DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
		Box(Modifier.fillMaxSize().background(Color.Black)) {
			VerticalPager(pager, Modifier.fillMaxSize().systemBarsPadding(), key = { shown[it].id }) { i ->
				val m = shown[i]
				Reel(m, app.person(m.userId), playing = resumed && pager.settledPage == i, muted = muted, onMute = { muted = !muted },
					open = { onClose(); open(it) },
					onShare = if (m.isVideo) null else ({ onShare(m) }),
					onDelete = if (m.userId == app.me?.id || app.me?.isAdmin == true) ({ deleting = m }) else null)
			}
			Box(
				Modifier.systemBarsPadding().padding(12.dp).size(44.dp).glassCircle()
					.pressable(onClose).semantics { contentDescription = "Voltar ao diário" },
				contentAlignment = Alignment.Center,
			) { Icon(IconName.Close, Color.White, size = 20.dp) }
		}
		deleting?.let { m ->
			AlertDialog(
				onDismissRequest = { deleting = null },
				title = { Text("Apagar esta foto/vídeo para todo mundo?") },
				text = { Text("Não dá para desfazer.") },
				confirmButton = {
					TextButton({
						deleting = null
						scope.launch {
							try {
								Api.delete("/api/media/${m.id}")
								gone = gone + m.id
								app.feedChanged()
								if (items.all { it.id in gone }) onClose()
							} catch (e: Exception) { app.handle(e) }
						}
					}) { Text("Apagar", color = Palette.danger) }
				},
				dismissButton = { TextButton({ deleting = null }) { Text("Cancelar") } },
			)
		}
	}
}

/** One full-screen page: the photo or looping video, the like/comments rail and who posted it. */
@Composable
private fun Reel(media: FeedMedia, person: Person?, playing: Boolean, muted: Boolean, onMute: () -> Unit, open: Opener, onShare: (() -> Unit)?, onDelete: (() -> Unit)?) {
	val app = LocalApp.current
	val scope = rememberCoroutineScope()
	val likers = remember { mutableStateMapOf<String, List<String>>() }
	val current = likers[media.id] ?: media.likers
	val favs = remember { mutableStateMapOf<String, List<String>>() }
	val favNow = favs[media.id] ?: media.favs
	fun setFav(on: Boolean) = scope.launch {
		val me = app.me?.id ?: return@launch
		val before = favNow
		favs[media.id] = if (on) before + me else before - me
		try { favs[media.id] = com.nelsul.curitibatrip.feature.feed.Favorites.set(media.id, on) } catch (e: Exception) {
			favs[media.id] = before
			app.handle(e)
		}
	}
	var bigHeart by remember { mutableIntStateOf(0) }
	var paused by remember { mutableStateOf(false) }
	LaunchedEffect(playing) { if (playing) paused = false }
	fun setLike(liked: Boolean) = scope.launch {
		val me = app.me?.id ?: return@launch
		if (liked == current.contains(me)) return@launch
		val before = current
		likers[media.id] = if (liked) before + me else before - me
		try {
			likers[media.id] = Api.post<LikeBody, LikeResponse>("/api/likes", LikeBody(mediaId = media.id, liked = liked)).likers
		} catch (e: Exception) {
			likers[media.id] = before
			app.handle(e)
		}
	}
	val ratio = if (media.width != null && media.height != null && media.height > 0) media.width.toFloat() / media.height else 1f

	Box(
		Modifier
			.fillMaxSize()
			.background(Color.Black)
			.pointerInput(media.id) {
				detectTapGestures(
					onDoubleTap = { bigHeart++; setLike(true) },
					onTap = { if (media.isVideo) paused = !paused },
				)
			}
			.semantics { contentDescription = "${if (media.isVideo) "Vídeo" else "Foto"} de ${person?.name ?: "alguém"}" },
		contentAlignment = Alignment.Center,
	) {
		if (media.isVideo && media.video != null) {
			ReelVideo(media.video, media.image, playing && !paused, muted, Modifier.fillMaxWidth().aspectRatio(ratio, matchHeightConstraintsFirst = ratio < 1f))
			if (!playing || paused) Icon(IconName.Play, Color.White.copy(alpha = 0.85f), size = 56.dp)
		} else {
			AsyncImage(media.image, null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize().pinchToZoom())
		}
		BigHeart(bigHeart)

		// who, when, caption
		Column(
			Modifier
				.align(Alignment.BottomStart)
				.fillMaxWidth()
				.background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.65f))))
				.padding(start = 14.dp, end = 80.dp, top = 48.dp, bottom = 18.dp),
			verticalArrangement = Arrangement.spacedBy(6.dp),
		) {
			// tapping who posted opens the details (the old "expand" button)
			Row(Modifier.pressable({ open(Route.Media(media.id)) }).semantics { contentDescription = "Abrir detalhes" },
				verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
				Avatar(person?.name ?: "?", colorOf(person?.color), person?.photo, size = 36.dp)
				Text(person?.name ?: "Alguém", style = display(17), color = Color.White)
				Text(TripTime.instant(media.at)?.let { dateTime.format(it) } ?: "", style = body(13), color = Color.White.copy(alpha = 0.85f))
			}
			if (media.caption.isNotEmpty()) Text(media.caption, style = body(15), color = Color.White, maxLines = 3, overflow = TextOverflow.Ellipsis)
		}

		// sound and delete up top, away from the actions (no deleting by accident)
		Row(Modifier.align(Alignment.TopEnd).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
			if (media.isVideo && media.video != null) Box(
				Modifier.size(44.dp).glassCircle().pressable(onMute).semantics { contentDescription = if (muted) "Ligar o som" else "Desligar o som" },
				contentAlignment = Alignment.Center,
			) { Icon(if (muted) IconName.Mute else IconName.Sound, Color.White, size = 20.dp) }
			if (onDelete != null) Box(
				Modifier.size(44.dp).glassCircle().pressable(onDelete).semantics { contentDescription = "Apagar" },
				contentAlignment = Alignment.Center,
			) { Icon(IconName.Trash, Color.White, size = 20.dp) }
		}

		// frosted round buttons with a label under each (web Reel .glass): like, comment, star, frame, save
		val me = app.me?.id
		Column(
			Modifier.align(Alignment.BottomEnd).padding(end = 10.dp, bottom = 28.dp),
			horizontalAlignment = Alignment.CenterHorizontally,
			verticalArrangement = Arrangement.spacedBy(12.dp),
		) {
			GlassAction(if (current.isEmpty()) "Curtir" else "${current.size}", on = current.contains(me), onTint = Palette.berry) {
				LikeButton(current.contains(me)) { setLike(it) }
			}
			GlassAction(if (media.comments > 0) "${media.comments}" else "Comentar") {
				Box(Modifier.fillMaxSize().pressable({ open(Route.Media(media.id)) }).semantics { contentDescription = "Comentários" }, contentAlignment = Alignment.Center) {
					Icon(IconName.Chat, Color.White, size = 24.dp)
				}
			}
			GlassAction(if (favNow.size > 1) "${favNow.size}" else "Favorito", on = favNow.contains(me), onTint = Palette.sun) {
				com.nelsul.curitibatrip.feature.feed.FavButton(favNow.contains(me), Color.White, 25.dp) { setFav(it) }
			}
			if (onShare != null) GlassAction("Moldura") {
				Box(Modifier.fillMaxSize().pressable(onShare).semantics { contentDescription = "Compartilhar com moldura" }, contentAlignment = Alignment.Center) {
					Icon(IconName.Frame, Color.White, size = 24.dp)
				}
			}
			GlassAction("Salvar") { com.nelsul.curitibatrip.feature.feed.SaveOriginalButton(media, Color.White, 24.dp) }
		}
	}
}

/** One reel action: a dark see-through circle with a thin light ring, and a label under it. */
@Composable
private fun GlassAction(label: String, on: Boolean = false, onTint: Color = Color.White, content: @Composable () -> Unit) {
	Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
		Box(Modifier.size(48.dp).glassCircle(if (on) onTint else null), contentAlignment = Alignment.Center) { content() }
		Text(label, style = body(11, FontWeight.ExtraBold).copy(shadow = androidx.compose.ui.graphics.Shadow(Color.Black.copy(alpha = 0.8f), blurRadius = 4f)),
			color = Color.White, maxLines = 1)
	}
}

/** Reels buttons: dark see-through circle with a light ring; `tint` colors it when the action is on. */
private fun Modifier.glassCircle(tint: Color? = null): Modifier =
	shadow(7.dp, CircleShape, clip = false, ambientColor = Color.Black.copy(alpha = 0.3f), spotColor = Color.Black.copy(alpha = 0.3f))
		.background(tint?.copy(alpha = 0.3f) ?: Color(0xFF141824).copy(alpha = 0.55f), CircleShape)
		.border(1.5.dp, (tint ?: Color.White).copy(alpha = if (tint == null) 0.22f else 0.55f), CircleShape)
		.clip(CircleShape)

@Composable
private fun Count(n: Int) = Text("$n", style = body(13, FontWeight.ExtraBold), color = Color.White, modifier = Modifier.padding(bottom = 2.dp))

/** A looping video that only plays while it's the page on screen; the poster shows until its first frame. */
@Composable
private fun ReelVideo(url: String, poster: String?, playing: Boolean, muted: Boolean, modifier: Modifier) {
	var player by remember { mutableStateOf<MediaPlayer?>(null) }
	var rendering by remember { mutableStateOf(false) }
	Box(modifier, contentAlignment = Alignment.Center) {
		AndroidView(
			factory = { ctx ->
				VideoView(ctx).apply {
					setOnPreparedListener { mp ->
						mp.isLooping = true
						player = mp
					}
					setOnInfoListener { _, what, _ ->
						if (what == MediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START) rendering = true
						false
					}
					setVideoURI(com.nelsul.curitibatrip.data.VideoCache.playable(url))
				}
			},
			update = { v -> if (playing) v.start() else if (v.isPlaying) v.pause() },
			onRelease = { it.stopPlayback(); player = null },
			modifier = Modifier.fillMaxSize(),
		)
		if (!rendering) AsyncImage(poster, null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize().background(Color.Black))
	}
	LaunchedEffect(player, muted) { player?.let { val v = if (muted) 0f else 1f; runCatching { it.setVolume(v, v) } } }
}
