package com.nelsul.curitibatrip.ui.components

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.nelsul.curitibatrip.ui.theme.Depth
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.bounce
import com.nelsul.curitibatrip.ui.theme.display

enum class ButtonVariant(val fill: Color, val edge: Color, val ink: Color, val border: Color?) {
	Leaf(Palette.leaf, Palette.leafDark, Palette.onLeaf, null),
	Sea(Palette.sea, Palette.seaDark, Palette.onSea, null),
	Sun(Palette.sun, Palette.sunDark, Palette.onSun, null),
	Secondary(Palette.surface, Palette.shadow, Palette.ink, Palette.line),
	Danger(Palette.surface, Palette.shadow, Palette.danger, Palette.danger),
	Uber(Color(0xFF1A1A1A), Color.Black, Color.White, null),
}

/** Click without the Material ripple; shrinks a little while pressed (cards, tiles, chips). */
fun Modifier.pressable(onClick: () -> Unit, enabled: Boolean = true): Modifier = composed {
	val source = remember { MutableInteractionSource() }
	val pressed by source.collectIsPressedAsState()
	val scale by animateFloatAsState(if (pressed && enabled) 0.96f else 1f, bounce(), label = "press")
	graphicsLayer { scaleX = scale; scaleY = scale }
		.clickable(interactionSource = source, indication = null, enabled = enabled, role = Role.Button, onClick = onClick)
}

/** The web `.btn`: a pill with a solid darker edge underneath that presses down when tapped. */
@Composable
fun ChunkyButton(
	onClick: () -> Unit,
	modifier: Modifier = Modifier,
	variant: ButtonVariant = ButtonVariant.Leaf,
	small: Boolean = false,
	fullWidth: Boolean = false,
	enabled: Boolean = true,
	content: @Composable RowScope.() -> Unit,
) {
	val source = remember { MutableInteractionSource() }
	val pressed by source.collectIsPressedAsState()
	val down by animateDpAsState(if (pressed && enabled) Depth.press else 0.dp, tween(80), label = "down")
	val haptics = LocalHapticFeedback.current
	LaunchedEffect(pressed) { if (pressed && enabled) haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove) }
	val v = variant
	Row(
		modifier
			.then(if (fullWidth) Modifier.fillMaxWidth() else Modifier)
			.alpha(if (enabled) 1f else 0.55f)
			.offset(y = down)
			.drawBehind {
				val r = CornerRadius(size.height / 2)
				drawRoundRect(v.edge, topLeft = Offset(0f, (Depth.button - down).toPx().coerceAtLeast(1.dp.toPx())), size = size, cornerRadius = r)
				drawRoundRect(v.fill, cornerRadius = r)
				v.border?.let {
					val w = 2.5.dp.toPx()
					drawRoundRect(it, topLeft = Offset(w / 2, w / 2), size = Size(size.width - w, size.height - w), cornerRadius = CornerRadius(size.height / 2 - w / 2), style = Stroke(w))
				}
			}
			.clickable(interactionSource = source, indication = null, enabled = enabled, role = Role.Button, onClick = onClick)
			.heightIn(min = if (small) 38.dp else 46.dp)
			.padding(horizontal = if (small) 16.dp else 22.dp),
		horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
		verticalAlignment = Alignment.CenterVertically,
	) {
		CompositionLocalProvider(LocalContentColor provides v.ink, LocalTextStyle provides display(if (small) 15 else 17).copy(color = v.ink)) {
			content()
		}
	}
}

/** A ChunkyButton with just a label. */
@Composable
fun ChunkyButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, variant: ButtonVariant = ButtonVariant.Leaf, small: Boolean = false, fullWidth: Boolean = false, enabled: Boolean = true, icon: IconName? = null) {
	ChunkyButton(onClick, modifier, variant, small, fullWidth, enabled) {
		if (icon != null) Icon(icon, variant.ink, size = if (small) 18.dp else 20.dp)
		Text(text)
	}
}

/** A text link in the app's green ("Não chegou? Enviar de novo"). */
@Composable
fun TextLink(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, color: Color = Palette.leaf) {
	Text(text, style = com.nelsul.curitibatrip.ui.theme.body(15, androidx.compose.ui.text.font.FontWeight.ExtraBold), color = color,
		modifier = modifier.pressable(onClick).padding(vertical = 6.dp))
}
