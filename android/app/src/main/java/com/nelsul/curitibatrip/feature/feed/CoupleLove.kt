package com.nelsul.curitibatrip.feature.feed

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.CoupleLike
import com.nelsul.curitibatrip.data.Route
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display

/** Special effect when the bride or groom liked one of my posts. Shown once: the server remembers it was seen. */
@Composable
fun CoupleLoveDialog(likes: List<CoupleLike>, done: (Route?) -> Unit) {
	val app = LocalApp.current
	val roles = likes.map { it.role }.toSet()
	val who = if (roles.size > 1) "Os noivos" else if ("noiva" in roles) "A noiva" else "O noivo"
	val likers = likes.map { it.likerId }.distinct().mapNotNull { app.person(it) }
	val posts = likes.map { it.mediaId ?: it.checkinId }.distinct().size
	val fall = rememberInfiniteTransition(label = "hearts")
	val t by fall.animateFloat(0f, 1f, infiniteRepeatable(tween(3000, easing = LinearEasing)), label = "fall")
	val beat by fall.animateFloat(1f, 1.2f, infiniteRepeatable(tween(500), RepeatMode.Reverse), label = "beat")
	Dialog({ done(null) }, DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
		BoxWithConstraints(
			Modifier.fillMaxSize().background(Brush.radialGradient(listOf(Palette.berry.copy(alpha = 0.5f), Palette.bg.copy(alpha = 0.95f)))),
			contentAlignment = Alignment.Center,
		) {
			val h = maxHeight
			val w = maxWidth
			repeat(26) { i ->
				val phase = (t + (i * 13 % 20) / 20f) % 1f
				Icon(if (i % 4 == 0) IconName.Ring else IconName.Heart, if (i % 3 == 0) Palette.sun else Palette.berry,
					Modifier.align(Alignment.TopStart).offset(x = w * ((i * 37 % 100) / 100f), y = (h + 80.dp) * phase - 40.dp).rotate(phase * 40f),
					size = (16 + i * 11 % 28).dp)
			}
			Column(
				Modifier.padding(16.dp).widthIn(max = 360.dp).background(Palette.bg, RoundedCornerShape(22.dp)).border(3.dp, Palette.berry, RoundedCornerShape(22.dp)).padding(24.dp),
				horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
			) {
				Box(Modifier.padding(top = 8.dp)) {
					AsyncImage(likes.first().image, null, contentScale = ContentScale.Crop,
						modifier = Modifier.size(180.dp).rotate(-4f).clip(RoundedCornerShape(18.dp)).border(6.dp, Color.White, RoundedCornerShape(18.dp)))
					Row(Modifier.align(Alignment.BottomEnd).offset(x = 22.dp, y = 18.dp)) { likers.forEach { p -> Avatar(p.name, colorOf(p.color), p.photo, 56.dp) } }
					Box(Modifier.offset(x = (-18).dp, y = (-18).dp).size(56.dp).scale(beat).background(Palette.berry, CircleShape), contentAlignment = Alignment.Center) {
						Icon(IconName.Heart, Color.White, size = 30.dp)
					}
				}
				Text("$who ${if (roles.size > 1) "curtiram" else "curtiu"} ${if (posts > 1) "$posts posts seus" else "seu post"}!",
					style = display(24), color = Palette.berry, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 14.dp))
				Text("${likers.joinToString(" e ") { it.name }} ${if (likers.size > 1) "deixaram" else "deixou"} um coração para você.",
					style = body(16), color = Palette.ink, textAlign = TextAlign.Center)
				Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
					ChunkyButton("Fechar", { done(null) }, variant = ButtonVariant.Secondary, small = true)
					ChunkyButton("Ver o post", {
						val l = likes.first()
						done(l.mediaId?.let { Route.Media(it) } ?: l.checkinId?.let { Route.Checkin(it) })
					}, variant = ButtonVariant.Sun, small = true)
				}
			}
		}
	}
}
