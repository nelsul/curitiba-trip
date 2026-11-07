package com.nelsul.curitibatrip.ui.theme

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.graphics.graphicsLayer
import kotlinx.coroutines.delay

/** The web `--bounce` curve as a spring (iOS: response 0.45, damping 0.6). */
fun <T> bounce() = spring<T>(dampingRatio = 0.6f, stiffness = 195f)
fun <T> snappy() = spring<T>(dampingRatio = 0.55f, stiffness = Spring.StiffnessMediumLow)

/** The web `pop-in` entrance: scale 0.4 → 1 with a little overshoot, fading in. */
fun Modifier.popIn(delayMs: Long = 0): Modifier = composed {
	val p = remember { Animatable(0f) }
	LaunchedEffect(Unit) {
		if (delayMs > 0) delay(delayMs)
		p.animateTo(1f, bounce())
	}
	graphicsLayer {
		val v = p.value
		scaleX = 0.4f + 0.6f * v
		scaleY = 0.4f + 0.6f * v
		alpha = v.coerceIn(0f, 1f)
	}
}
