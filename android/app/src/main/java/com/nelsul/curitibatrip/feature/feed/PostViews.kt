package com.nelsul.curitibatrip.feature.feed

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.FeedCheckin
import com.nelsul.curitibatrip.data.FeedMedia
import com.nelsul.curitibatrip.data.LikeBody
import com.nelsul.curitibatrip.data.LikeResponse
import com.nelsul.curitibatrip.data.Person
import com.nelsul.curitibatrip.data.Route
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.HeartShape
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.bounce
import com.nelsul.curitibatrip.ui.theme.display
import com.nelsul.curitibatrip.ui.theme.popIn
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin

/** Opens a photo/video or check-in page. */
typealias Opener = (Route) -> Unit

private fun Modifier.postFrame() = this
	.fillMaxWidth()
	.background(Palette.surface)
	.drawBehind {
		val w = 2.5.dp.toPx()
		drawRect(Palette.line, size = androidx.compose.ui.geometry.Size(size.width, w))
		drawRect(Palette.line, topLeft = Offset(0f, size.height - w), size = androidx.compose.ui.geometry.Size(size.width, w))
	}

/** Avatar + name + subtitle, shared by both post kinds. */
@Composable
private fun PostHeader(person: Person?, subtitle: String, trailing: (@Composable () -> Unit)? = null) {
	Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
		Avatar(person?.name ?: "?", person?.let { colorOf(it.color) } ?: Palette.muted, person?.photo, 40.dp)
		Column(Modifier.weight(1f)) {
			Text(person?.name ?: "Alguém", style = display(17), color = Palette.ink)
			Text(subtitle, style = body(13), color = Palette.muted)
		}
		trailing?.invoke()
	}
}

/** A photo/video post: swipeable carousel, double-tap to like, heart, liked-by, caption, comments. */
@Composable
fun MediaPost(items: List<FeedMedia>, person: Person?, open: Opener) {
	val openReel = LocalOpenReel.current
	val app = LocalApp.current
	val scope = rememberCoroutineScope()
	val pager = rememberPagerState { items.size }
	val likers = remember { mutableStateMapOf<String, List<String>>() }
	var bigHeart by remember { mutableIntStateOf(0) }
	val current = items[pager.currentPage.coerceIn(0, items.size - 1)]
	// same frame as the web: between 4:5 portrait and 1.91:1 landscape, from the first item
	val ratio = items.first().let { m -> if (m.width != null && m.height != null && m.height > 0) (m.width.toFloat() / m.height).coerceIn(0.8f, 1.91f) else 1f }
	fun likersOf(m: FeedMedia) = likers[m.id] ?: m.likers
	fun setLike(m: FeedMedia, liked: Boolean) = scope.launch {
		val me = app.me?.id ?: return@launch
		val before = likersOf(m)
		if (liked == before.contains(me)) return@launch
		likers[m.id] = if (liked) before + me else before - me // optimistic
		try {
			likers[m.id] = Api.post<LikeBody, LikeResponse>("/api/likes", LikeBody(mediaId = m.id, liked = liked)).likers
		} catch (e: Exception) {
			likers[m.id] = before
			app.handle(e)
		}
	}
	val first = TripTime.time(items.first().at)
	val last = TripTime.time(items.last().at)

	Column(Modifier.popIn().postFrame()) {
		PostHeader(person, if (items.size > 1 && first != last) "$first–$last" else first) {
			if (items.size > 1) Text("${pager.currentPage + 1}/${items.size}", style = body(13, FontWeight.ExtraBold), color = Palette.ink,
				modifier = Modifier.background(Palette.surface2, CircleShape).border(2.dp, Palette.line, CircleShape).padding(horizontal = 8.dp))
		}
		Box(Modifier.fillMaxWidth().aspectRatio(ratio).background(Color.Black)) {
			HorizontalPager(pager, Modifier.fillMaxSize()) { i ->
				MediaSlide(items[i], Modifier.pointerInput(items[i].id) {
					detectTapGestures(
						onDoubleTap = { if (!items[i].isVideo) { bigHeart++; setLike(items[i], true) } },
						onTap = { if (items[i].status == "ready" && openReel != null) openReel(items[i].id) else open(Route.Media(items[i].id)) },
					)
				})
			}
			BigHeart(bigHeart)
		}
		Row(Modifier.fillMaxWidth().padding(horizontal = 6.dp), verticalAlignment = Alignment.CenterVertically) {
			LikeButton(likersOf(current).contains(app.me?.id)) { setLike(current, it) }
			Icon(IconName.Chat, Palette.ink, Modifier.pressable({ open(Route.Media(current.id)) }).padding(9.dp).semantics { contentDescription = "Comentários" }, size = 26.dp)
			Icon(IconName.Expand, Palette.ink, Modifier.pressable({ if (current.status == "ready" && openReel != null) openReel(current.id) else open(Route.Media(current.id)) }).padding(10.dp).semantics { contentDescription = "Abrir em tela cheia" }, size = 24.dp)
			Spacer(Modifier.weight(1f))
			if (items.size > 1) Dots(items.size, pager.currentPage)
			Spacer(Modifier.width(92.dp))
		}
		Column(Modifier.padding(start = 14.dp, end = 14.dp, bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
			LikedBy(likersOf(current))
			if (current.caption.isNotEmpty()) Caption(person?.name ?: "", current.caption)
			CommentPreview(current.firstComments, current.comments) { open(Route.Media(current.id)) }
		}
	}
}

@Composable
private fun Caption(name: String, text: String) {
	Text(buildAnnotatedString {
		withStyle(SpanStyle(fontWeight = FontWeight.ExtraBold)) { append(name) }
		append("  ")
		append(text)
	}, style = body(16), color = Palette.ink)
}

@Composable
private fun MediaSlide(media: FeedMedia, modifier: Modifier) {
	Box(modifier.fillMaxSize().clipToBounds(), contentAlignment = Alignment.Center) {
		if ((media.status == "preview" || media.status == "processing") && media.image != null) {
			// waiting for Wi-Fi on the sender's phone (or the original is being processed): the low-res picture for now
			AsyncImage(media.image, contentDescription = media.caption.ifEmpty { "Foto" }, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
			Row(
				Modifier.align(Alignment.BottomStart).padding(8.dp).background(Color.Black.copy(alpha = 0.6f), RoundedCornerShape(12.dp)).padding(horizontal = 10.dp, vertical = 5.dp),
				verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
			) {
				Icon(IconName.Clock, Color.White, size = 13.dp)
				Text(if (media.status == "preview") "${if (media.isVideo) "Vídeo completo" else "Foto completa"} chega quando estiver no Wi‑Fi" else "Processando o original…",
					style = body(12, FontWeight.ExtraBold), color = Color.White)
			}
		} else if (media.status != "ready") {
			Text(
				when { media.status == "failed" -> "Não foi possível processar"; media.isVideo -> "Preparando o vídeo…"; else -> "Processando…" },
				style = body(15, FontWeight.ExtraBold), color = Color.White.copy(alpha = 0.85f),
			)
		} else {
			AsyncImage(media.image, contentDescription = if (media.isVideo) "Vídeo" else media.caption.ifEmpty { "Foto" }, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
		}
		if (media.isVideo && media.status == "ready") {
			Icon(IconName.Play, Color.White, size = 34.dp)
			media.durationS?.let { d ->
				Text("%d:%02d".format(d.toInt() / 60, d.toInt() % 60), style = body(12, FontWeight.ExtraBold), color = Color.White,
					modifier = Modifier.align(Alignment.TopEnd).padding(10.dp).background(Color.Black.copy(alpha = 0.6f), CircleShape).padding(horizontal = 8.dp, vertical = 2.dp))
			}
		}
	}
}

/** A check-in post: the map picture (or the teal banner until it exists), heart and note. */
@Composable
fun CheckinPost(checkin: FeedCheckin, person: Person?, open: Opener) {
	val app = LocalApp.current
	val scope = rememberCoroutineScope()
	var likers by remember { mutableStateOf<List<String>?>(null) }
	val current = likers ?: checkin.likers
	fun setLike(liked: Boolean) = scope.launch {
		val me = app.me?.id ?: return@launch
		val before = current
		likers = if (liked) before + me else before - me
		try {
			likers = Api.post<LikeBody, LikeResponse>("/api/likes", LikeBody(checkinId = checkin.id, liked = liked)).likers
		} catch (e: Exception) {
			likers = before
			app.handle(e)
		}
	}
	Column(Modifier.popIn().postFrame()) {
		PostHeader(person, "fez check-in · ${TripTime.time(checkin.at)}")
		Box(Modifier.fillMaxWidth().aspectRatio(3f / 2f).clipToBounds().pressable({ open(Route.Checkin(checkin.id)) }).semantics { contentDescription = "Abrir check-in" }) {
			if (checkin.snapshot != null) {
				AsyncImage(checkin.snapshot, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
			} else {
				Column(Modifier.fillMaxSize().background(Palette.sea), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
					Box(Modifier.size(64.dp).background(person?.let { colorOf(it.color) } ?: Palette.coral, CircleShape).border(4.dp, Color.White, CircleShape), contentAlignment = Alignment.Center) {
						Icon(IconName.Pin, Color.White, size = 34.dp)
					}
					Text("Ver no mapa ›", style = body(14, FontWeight.ExtraBold), color = Color.White, modifier = Modifier.padding(top = 10.dp))
				}
			}
		}
		Row(Modifier.fillMaxWidth().padding(horizontal = 6.dp), verticalAlignment = Alignment.CenterVertically) {
			LikeButton(current.contains(app.me?.id)) { setLike(it) }
			Icon(IconName.Chat, Palette.ink, Modifier.pressable({ open(Route.Checkin(checkin.id)) }).padding(9.dp).semantics { contentDescription = "Comentários" }, size = 26.dp)
		}
		Column(Modifier.padding(start = 14.dp, end = 14.dp, bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
			LikedBy(current)
			if (checkin.note.isNotEmpty()) Caption(person?.name ?: "", checkin.note)
			CommentPreview(checkin.firstComments, checkin.comments) { open(Route.Checkin(checkin.id)) }
		}
	}
}

/** The heart: fills pink, pops and throws little sparks when liked (web LikeButton). */
@Composable
fun LikeButton(liked: Boolean, toggle: (Boolean) -> Unit) {
	val haptics = LocalHapticFeedback.current
	var burst by remember { mutableIntStateOf(0) }
	val pop = remember { Animatable(1f) }
	val scope = rememberCoroutineScope()
	Box(
		Modifier
			.size(44.dp)
			.pressable({
				if (!liked) {
					burst++
					haptics.performHapticFeedback(HapticFeedbackType.LongPress)
					scope.launch { pop.snapTo(0.6f); pop.animateTo(1f, bounce()) }
				}
				toggle(!liked)
			})
			.semantics { contentDescription = if (liked) "Descurtir" else "Curtir" },
		contentAlignment = Alignment.Center,
	) {
		HeartShape(liked, if (liked) Palette.berry else Palette.ink, Modifier.scale(pop.value), size = 27.dp)
		Sparks(burst)
	}
}

@Composable
private fun Sparks(trigger: Int) {
	val p = remember { Animatable(1f) }
	androidx.compose.runtime.LaunchedEffect(trigger) {
		if (trigger == 0) return@LaunchedEffect
		p.snapTo(0f)
		p.animateTo(1f, tween(550, easing = FastOutSlowInEasing))
	}
	Canvas(Modifier.size(44.dp)) {
		if (p.value >= 1f) return@Canvas
		for (i in 0 until 6) {
			val a = Math.toRadians(i * 60.0 - 90)
			val d = 24.dp.toPx() * p.value
			drawCircle(if (i % 2 == 0) Palette.berry else Palette.sun, 3.dp.toPx(), center + Offset((cos(a) * d).toFloat(), (sin(a) * d).toFloat()), alpha = 1f - p.value)
		}
	}
}

/** The big white heart over a double-tapped photo. */
@Composable
internal fun BigHeart(trigger: Int) {
	val scale = remember { Animatable(0f) }
	val alpha = remember { Animatable(0f) }
	androidx.compose.runtime.LaunchedEffect(trigger) {
		if (trigger == 0) return@LaunchedEffect
		alpha.snapTo(1f)
		scale.snapTo(0.1f)
		scale.animateTo(1f, bounce())
		alpha.animateTo(0f, tween(300, delayMillis = 300))
	}
	Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
		HeartShape(true, Color.White, Modifier.graphicsLayer {
			scaleX = scale.value; scaleY = scale.value; this.alpha = alpha.value
			translationY = (1f - alpha.value) * -30.dp.toPx()
		}, size = 96.dp)
	}
}

@Composable
fun Dots(count: Int, index: Int) {
	Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
		repeat(count) { i ->
			val s by animateFloatAsState(if (i == index) 1.25f else 1f, bounce(), label = "dot")
			Box(Modifier.scale(s).size(7.dp).background(if (i == index) Palette.sea else Palette.line, CircleShape))
		}
	}
}

/** "Curtido por você e mais 2", with up to three tiny avatars. */
@Composable
fun LikedBy(likers: List<String>) {
	if (likers.isEmpty()) return
	val app = LocalApp.current
	val me = app.me?.id
	val ordered = likers.reversed().sortedByDescending { it == me }
	fun name(id: String) = if (id == me) "você" else app.person(id)?.name ?: "alguém"
	Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
		Row {
			ordered.take(3).forEachIndexed { i, id ->
				app.person(id)?.let { p -> Avatar(p.name, colorOf(p.color), p.photo, 22.dp, Modifier.offset(x = (-8 * i).dp)) }
			}
		}
		Text(buildAnnotatedString {
			append("Curtido por ")
			withStyle(SpanStyle(fontWeight = FontWeight.ExtraBold)) { append(name(ordered[0])) }
			when {
				likers.size == 2 -> { append(" e "); withStyle(SpanStyle(fontWeight = FontWeight.ExtraBold)) { append(name(ordered[1])) } }
				likers.size > 2 -> { append(" e "); withStyle(SpanStyle(fontWeight = FontWeight.ExtraBold)) { append("mais ${likers.size - 1}") } }
			}
		}, style = body(15), color = Palette.ink, modifier = Modifier.offset(x = (-8 * (minOf(3, ordered.size) - 1)).dp))
	}
}

/** The first two comments under a post (Instagram-style), and a link to the rest (as on the web). */
@Composable
private fun CommentPreview(first: List<com.nelsul.curitibatrip.data.PreviewComment>, total: Int, onOpen: () -> Unit) {
	val app = LocalApp.current
	first.forEach { c ->
		Text(buildAnnotatedString {
			withStyle(SpanStyle(fontWeight = FontWeight.ExtraBold)) { append(app.person(c.userId)?.name ?: "Alguém") }
			append("  ")
			append(com.nelsul.curitibatrip.feature.detail.Mentions.highlight(c.body, app.people))
		}, style = body(15), color = Palette.ink, maxLines = 2, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
			modifier = Modifier.fillMaxWidth().pressable(onOpen))
	}
	if (total > first.size) Text(
		if (first.isEmpty()) (if (total == 1) "Ver 1 comentário" else "Ver os $total comentários") else "Ver todos os $total comentários",
		style = body(14, FontWeight.Bold), color = Palette.muted, modifier = Modifier.pressable(onOpen),
	)
}
