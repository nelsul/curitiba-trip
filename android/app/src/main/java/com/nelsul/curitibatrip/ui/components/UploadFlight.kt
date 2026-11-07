package com.nelsul.curitibatrip.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.display
import kotlin.math.cos
import kotlin.math.sin

/**
 * The upload progress bar (web UploadFlight): a plane flies along a dotted route from the camera to the island;
 * on arrival a "Chegou!" stamp lands with a burst of confetti.
 */
@Composable
fun UploadFlight(progress: Float, done: Boolean, failed: Boolean, modifier: Modifier = Modifier) {
	val pct by animateFloatAsState(if (done) 1f else progress.coerceIn(0f, 1f), tween(300), label = "pct")
	val bob by rememberInfiniteTransition(label = "bob").animateFloat(-1f, 1f, infiniteRepeatable(tween(600), RepeatMode.Reverse), label = "b")
	val land by animateFloatAsState(if (done) 1f else 0f, tween(500), label = "land")
	Box(modifier.fillMaxWidth().height(40.dp).semantics { contentDescription = if (done) "Enviado" else "Envio ${(pct * 100).toInt()}%" }) {
		Row(Modifier.fillMaxWidth().height(36.dp).padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
			End(IconName.Camera, on = false)
			BoxWithConstraints(Modifier.weight(1f).height(24.dp).padding(horizontal = 10.dp)) {
				val w = maxWidth
				Canvas(Modifier.fillMaxWidth().height(24.dp)) {
					val y = size.height / 2
					var x = 2f
					val step = 10.dp.toPx()
					while (x <= size.width - 2f) {
						drawCircle(if (x <= size.width * pct) Palette.sea else Palette.line, 2.2.dp.toPx(), Offset(x, y))
						x += step
					}
				}
				Icon(
					IconName.Plane, if (failed) Palette.danger else Palette.sea,
					Modifier
						.offset(x = w * pct - 11.dp, y = 1.dp + (if (failed || done) 0f else bob * 2f).dp)
						.rotate(90f + if (failed || done) 0f else bob * 3f)
						.graphicsLayer { alpha = 1f - land; scaleX = 1f - 0.4f * land; scaleY = 1f - 0.4f * land },
					size = 22.dp,
				)
			}
			End(IconName.Island, on = done)
		}
		AnimatedVisibility(done, Modifier.align(Alignment.TopEnd).offset(x = (-30).dp, y = (-14).dp), enter = scaleIn(initialScale = 2.2f) + fadeIn()) {
			Text("CHEGOU!", style = display(15).copy(letterSpacing = 1.sp), color = Palette.coral,
				modifier = Modifier.rotate(-8f).background(Palette.surface, RoundedCornerShape(8.dp)).border(2.5.dp, Palette.coral, RoundedCornerShape(8.dp)).padding(horizontal = 8.dp, vertical = 1.dp))
		}
		if (done) Confetti(Modifier.align(Alignment.CenterEnd).offset(x = (-14).dp))
	}
}

@Composable
private fun End(icon: IconName, on: Boolean) {
	Box(
		Modifier.size(28.dp).background(if (on) Palette.leaf else Palette.surface2, CircleShape).border(2.dp, if (on) Palette.leaf else Palette.line, CircleShape),
		contentAlignment = Alignment.Center,
	) { Icon(icon, if (on) Palette.onLeaf else Palette.muted, size = 16.dp) }
}

/** Twelve bits of paper flying out in a circle. */
@Composable
private fun Confetti(modifier: Modifier) {
	val p = remember { Animatable(0f) }
	LaunchedEffect(Unit) { p.animateTo(1f, tween(900, easing = CubicBezierEasing(0.2f, 0.8f, 0.3f, 1f))) }
	val colors = listOf(Palette.leaf, Palette.sun, Palette.coral, Palette.sea, Palette.berry)
	Canvas(modifier.size(1.dp)) {
		if (p.value >= 1f) return@Canvas
		for (i in 0 until 12) {
			val a = Math.toRadians(i / 12.0 * 360 + if (i % 2 == 1) 12 else -8)
			val d = (34 + (i % 3) * 12).dp.toPx() * p.value
			val c = center + Offset((cos(a) * d).toFloat(), (sin(a) * d).toFloat() + 10.dp.toPx() * p.value)
			drawLine(colors[i % 5], c, c + Offset(5.dp.toPx(), 0f), 5.dp.toPx(), StrokeCap.Round, alpha = 1f - p.value)
		}
	}
}

