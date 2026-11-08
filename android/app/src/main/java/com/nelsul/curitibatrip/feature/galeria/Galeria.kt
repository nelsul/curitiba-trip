package com.nelsul.curitibatrip.feature.galeria

import android.media.MediaPlayer
import android.net.Uri
import android.widget.VideoView
import androidx.compose.foundation.background
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
import com.nelsul.curitibatrip.AppState
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.FeedMedia
import com.nelsul.curitibatrip.data.FeedPage
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

/** Every photo and video (no check-ins), newest first, paged through GET /api/feed. */
class GaleriaModel {
	var items by mutableStateOf<List<FeedMedia>>(emptyList())
		private set
	var loading by mutableStateOf(false)
		private set
	var error by mutableStateOf<String?>(null)
		private set
	private var cursor: String? = null
	private var reachedEnd = false

	suspend fun refresh(app: AppState) {
		cursor = null
		reachedEnd = false
		load(app, replace = true)
	}

	/** Loads the next page a few items before the end, so swiping never waits. */
	suspend fun loadMoreIfNeeded(index: Int, app: AppState) {
		if (reachedEnd || loading || index < items.size - 4) return
		load(app, replace = false)
	}

	private suspend fun load(app: AppState, replace: Boolean) {
		loading = true
		try {
			val found = mutableListOf<FeedMedia>()
			var first = true
			// a page may be all check-ins: keep going until there's something to show
			do {
				val page: FeedPage = Api.get("/api/feed", mapOf("limit" to "30", "before" to if (replace && first) null else cursor))
				first = false
				for (post in page.posts) {
					// carousels are oldest → newest inside; the Galeria is newest first
					if (post.type == "media") found += post.items.reversed().filter { it.status == "ready" && (it.image != null || it.video != null) }
				}
				cursor = page.nextCursor
				reachedEnd = page.nextCursor == null
			} while (found.isEmpty() && !reachedEnd)
			items = if (replace) found else items + found.filter { f -> items.none { it.id == f.id } }
			error = null
		} catch (e: Exception) {
			app.handle(e)
			error = e.message
		} finally {
			loading = false
		}
	}
}

private val dateTime = DateTimeFormatter.ofPattern("dd/MM, HH:mm", TripTime.locale).withZone(TripTime.zone)

/**
 * Galeria: full-screen photos and videos, swiping up like Reels. Only the page on screen plays, and nothing plays
 * while a detail page covers the Galeria, another tab is open or the app is in the background.
 */
@Composable
fun GaleriaScreen(contentPadding: PaddingValues, open: Opener, covered: Boolean) {
	val app = LocalApp.current
	val model = remember { GaleriaModel() }
	val pager = rememberPagerState { model.items.size }
	var resumed by remember { mutableStateOf(true) }
	var muted by remember { mutableStateOf(false) }
	LifecycleResumeEffect(Unit) {
		resumed = true
		onPauseOrDispose { resumed = false }
	}
	LaunchedEffect(app.feedVersion) { model.refresh(app) }
	LaunchedEffect(pager) { snapshotFlow { pager.currentPage }.collect { model.loadMoreIfNeeded(it, app) } }

	// the floating dock covers the bottom: pages end above it
	Box(Modifier.fillMaxSize().padding(bottom = 96.dp).background(Color.Black)) {
		when {
			model.items.isNotEmpty() -> VerticalPager(pager, Modifier.fillMaxSize(), key = { model.items[it].id }) { i ->
				val m = model.items[i]
				Reel(m, app.person(m.userId), playing = resumed && !covered && pager.settledPage == i, muted = muted, onMute = { muted = !muted }, open = open)
			}
			model.loading -> CircularProgressIndicator(Modifier.align(Alignment.Center), color = Palette.sea)
			else -> Box(Modifier.fillMaxSize().background(Palette.bg).padding(16.dp), contentAlignment = Alignment.Center) {
				EmptyState(model.error ?: "Nenhuma foto ou vídeo ainda.", if (model.error != null) ({ app.feedChanged() }) else null)
			}
		}
	}
}

/** One full-screen page: the photo or looping video, the like/comments rail and who posted it. */
@Composable
private fun Reel(media: FeedMedia, person: Person?, playing: Boolean, muted: Boolean, onMute: () -> Unit, open: Opener) {
	val app = LocalApp.current
	val scope = rememberCoroutineScope()
	val likers = remember { mutableStateMapOf<String, List<String>>() }
	val current = likers[media.id] ?: media.likers
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
			Box(
				Modifier.align(Alignment.TopEnd).padding(12.dp).size(44.dp).background(Color.Black.copy(alpha = 0.45f), CircleShape)
					.pressable(onMute).semantics { contentDescription = if (muted) "Ligar o som" else "Desligar o som" },
				contentAlignment = Alignment.Center,
			) { Icon(if (muted) IconName.Mute else IconName.Sound, Color.White, size = 20.dp) }
		} else {
			AsyncImage(media.image, null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize())
		}
		BigHeart(bigHeart)

		// who, when, caption
		Column(
			Modifier
				.align(Alignment.BottomStart)
				.fillMaxWidth()
				.background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.65f))))
				.padding(start = 14.dp, end = 72.dp, top = 48.dp, bottom = 18.dp),
			verticalArrangement = Arrangement.spacedBy(6.dp),
		) {
			Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
				Avatar(person?.name ?: "?", colorOf(person?.color), person?.photo, size = 36.dp)
				Text(person?.name ?: "Alguém", style = display(17), color = Color.White)
				Text(TripTime.instant(media.at)?.let { dateTime.format(it) } ?: "", style = body(13), color = Color.White.copy(alpha = 0.85f))
			}
			if (media.caption.isNotEmpty()) Text(media.caption, style = body(15), color = Color.White, maxLines = 3, overflow = TextOverflow.Ellipsis)
		}

		// like, comments, details
		Column(
			Modifier.align(Alignment.BottomEnd).padding(end = 6.dp, bottom = 18.dp),
			horizontalAlignment = Alignment.CenterHorizontally,
		) {
			LikeButton(current.contains(app.me?.id)) { setLike(it) }
			if (current.isNotEmpty()) Count(current.size)
			Icon(IconName.Chat, Color.White, Modifier.padding(top = 6.dp).pressable({ open(Route.Media(media.id)) }).padding(9.dp).semantics { contentDescription = "Comentários" }, size = 28.dp)
			if (media.comments > 0) Count(media.comments)
			Icon(IconName.Expand, Color.White, Modifier.padding(top = 6.dp).pressable({ open(Route.Media(media.id)) }).padding(10.dp).semantics { contentDescription = "Abrir detalhes" }, size = 26.dp)
		}
	}
}

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
					setVideoURI(Uri.parse(url))
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
