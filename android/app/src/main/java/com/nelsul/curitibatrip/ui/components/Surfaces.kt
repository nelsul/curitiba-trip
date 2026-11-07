package com.nelsul.curitibatrip.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nelsul.curitibatrip.ui.theme.Depth
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.Radius
import com.nelsul.curitibatrip.ui.theme.display

/** The navy background with the soft polka dots used behind every screen. */
@Composable
fun DottedBackground(modifier: Modifier = Modifier) {
	Canvas(modifier.fillMaxSize()) {
		drawRect(Palette.bg)
		val step = 28.dp.toPx()
		val r = 2.dp.toPx()
		var y = 0f
		while (y <= size.height + step) {
			var x = 0f
			while (x <= size.width + step) {
				drawCircle(Palette.bgDot, r, Offset(x, y))
				drawCircle(Palette.bgDot, r, Offset(x + step / 2, y + step / 2))
				x += step
			}
			y += step
		}
	}
}

/**
 * A rounded shape with a solid darker edge underneath (the web's "chunky" look), drawn behind the content.
 * `border` is drawn inside the shape.
 */
fun Modifier.chunky(fill: Color, edge: Color, radius: Dp, depth: Dp, border: Color? = null, borderWidth: Dp = 2.5.dp): Modifier =
	this
		.drawBehind {
			val r = CornerRadius(radius.toPx().coerceAtMost(size.minDimension / 2))
			drawRoundRect(edge, topLeft = Offset(0f, depth.toPx()), size = size, cornerRadius = r)
			drawRoundRect(fill, cornerRadius = r)
			if (border != null) {
				val w = borderWidth.toPx()
				drawRoundRect(border, topLeft = Offset(w / 2, w / 2), size = Size(size.width - w, size.height - w),
					cornerRadius = CornerRadius((r.x - w / 2).coerceAtLeast(0f)), style = Stroke(w))
			}
		}

/** The web `.card`: surface, 2.5 dp border and a solid shadow edge underneath. */
fun Modifier.card(padding: Dp = 16.dp, radius: Dp = Radius.card): Modifier =
	chunky(Palette.surface, Palette.shadow, radius, Depth.card, border = Palette.line).padding(padding)

/** A rotated, dashed "passport stamp" label (e.g. 11–18/11). */
@Composable
fun Stamp(text: String, color: Color = Palette.coral, size: Int = 13) {
	Text(
		text,
		style = display(size),
		color = color,
		modifier = Modifier
			.rotate(-4f)
			.drawBehind {
				val w = 2.5.dp.toPx()
				drawRoundRect(
					color, topLeft = Offset(w / 2, w / 2), size = Size(this.size.width - w, this.size.height - w),
					cornerRadius = CornerRadius(9.dp.toPx()),
					style = Stroke(w, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 3.dp.toPx()))),
				)
			}
			.padding(horizontal = 7.dp, vertical = 1.dp),
	)
}

/** Pill chip (filters). `dashed` = the passport-stamp day chips. */
@Composable
fun Chip(selected: Boolean, onClick: () -> Unit, dashed: Boolean = false, tint: Color? = null, content: @Composable BoxScope.() -> Unit) {
	val fill = if (selected) Palette.sea else Palette.surface
	val edge = if (selected) Palette.seaDark else Palette.shadow
	val line = if (selected) Palette.sea else (tint ?: Palette.line)
	Box(
		Modifier
			.heightIn(min = 38.dp)
			.drawBehind {
				val r = CornerRadius(size.height / 2)
				drawRoundRect(edge, topLeft = Offset(0f, Depth.chip.toPx()), size = size, cornerRadius = r)
				drawRoundRect(fill, cornerRadius = r)
				val w = 2.5.dp.toPx()
				drawRoundRect(
					line, topLeft = Offset(w / 2, w / 2), size = Size(size.width - w, size.height - w), cornerRadius = CornerRadius(size.height / 2 - w / 2),
					style = Stroke(w, pathEffect = if (dashed && !selected) PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 4.dp.toPx())) else null),
				)
			}
			.pressable(onClick)
			.padding(horizontal = 16.dp),
		contentAlignment = Alignment.Center,
	) {
		androidx.compose.runtime.CompositionLocalProvider(
			androidx.compose.material3.LocalContentColor provides if (selected) Palette.onSea else (tint ?: Palette.ink),
		) { content() }
	}
}
