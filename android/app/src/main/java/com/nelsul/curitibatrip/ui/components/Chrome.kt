package com.nelsul.curitibatrip.ui.components

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import com.nelsul.curitibatrip.ui.theme.snappy

/** A rounded tile with a solid edge under it (the tilted icon tiles). */
private fun Modifier.tile(fill: Color, edge: Color, radius: Float, depth: Float) = drawBehind {
	val r = CornerRadius(radius * density)
	drawRoundRect(edge, topLeft = Offset(0f, depth * density), size = size, cornerRadius = r)
	drawRoundRect(fill, cornerRadius = r)
}

/** Top bar: plane tile + "Curitiba" + the dates stamp, with the dashed bottom edge. */
@Composable
fun TopBar() {
	Row(
		Modifier
			.fillMaxWidth()
			.background(Palette.bg.copy(alpha = 0.92f))
			.drawBehind {
				val w = 2.5.dp.toPx()
				drawLine(Palette.line, Offset(0f, size.height - w / 2), Offset(size.width, size.height - w / 2), w,
					pathEffect = PathEffect.dashPathEffect(floatArrayOf(8.dp.toPx(), 6.dp.toPx())))
			}
			.padding(horizontal = 16.dp, vertical = 10.dp)
			.semantics(mergeDescendants = true) { contentDescription = "Viagem a Curitiba, 11 a 18 de novembro" },
		verticalAlignment = Alignment.CenterVertically,
		horizontalArrangement = Arrangement.spacedBy(8.dp),
	) {
		Box(Modifier.rotate(-8f).size(36.dp).tile(Palette.sea, Palette.seaDark, 12f, 3f), contentAlignment = Alignment.Center) {
			Icon(IconName.Plane, Color.White, Modifier.rotate(90f), size = 18.dp)
		}
		Text("Curitiba", style = display(24), color = Palette.ink)
		Stamp("11–18/11", size = 12)
	}
}

/** Title row: a tilted sun-colored icon tile + the screen title ("Diário da viagem"). */
@Composable
fun TitleRow(icon: IconName, title: String, modifier: Modifier = Modifier) {
	Row(modifier.semantics(mergeDescendants = true) { heading() }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
		Box(Modifier.rotate(-6f).size(48.dp).tile(Palette.sun, Palette.sunDark, 16f, 4f), contentAlignment = Alignment.Center) {
			Icon(icon, Palette.onSun, size = 26.dp)
		}
		Text(title, style = display(32), color = Palette.ink)
	}
}

/** The wooden sign with the day ("Sexta-feira, 13 de novembro"). */
@Composable
fun DaySign(text: String, modifier: Modifier = Modifier) {
	Text(
		text,
		style = display(18).copy(shadow = androidx.compose.ui.graphics.Shadow(Palette.woodShadow, Offset(0f, 2f), 0f)),
		color = Palette.onWood,
		textAlign = TextAlign.Center,
		modifier = modifier
			.semantics { heading() }
			.drawBehind {
				val r = CornerRadius(12.dp.toPx())
				drawRoundRect(Palette.woodShadow, topLeft = Offset(0f, 4.dp.toPx()), size = size, cornerRadius = r)
				drawRoundRect(Brush.verticalGradient(listOf(Palette.wood, Palette.woodDark)), cornerRadius = r)
				val w = 2.5.dp.toPx()
				drawRoundRect(Palette.woodEdge, topLeft = Offset(w / 2, w / 2), size = Size(size.width - w, size.height - w), cornerRadius = CornerRadius(r.x - w / 2), style = Stroke(w))
			}
			.padding(horizontal = 22.dp, vertical = 6.dp),
	)
}

enum class Tab(val label: String, val icon: IconName, val color: Color) {
	Diario("Diário", IconName.Journal, Palette.leaf),
	Mapa("Mapa", IconName.Map, Palette.sea),
	Enviar("Enviar", IconName.Upload, Palette.sun),
	Roteiro("Roteiro", IconName.Ticket, Palette.coral),
	Mais("Mais", IconName.User, Palette.plum),
}

/** The floating dock with colored icon tiles; "Enviar" is the raised yellow coin (same as the web and iOS). */
@Composable
fun Dock(selection: Tab, onSelect: (Tab) -> Unit, modifier: Modifier = Modifier) {
	val haptics = LocalHapticFeedback.current
	Row(
		modifier
			.padding(horizontal = 10.dp)
			.widthIn(max = 520.dp)
			.fillMaxWidth()
			// fill, border and shadow all behind the tabs, so the border never cuts through the raised coin
			.shadow(12.dp, RoundedCornerShape(28.dp), ambientColor = Color.Black.copy(alpha = 0.12f), spotColor = Color.Black.copy(alpha = 0.12f), clip = false)
			.chunky(Palette.surface, Palette.shadow, 28.dp, 5.dp, border = Palette.line)
			.padding(vertical = 8.dp),
	) {
		Tab.entries.forEach { tab ->
			val active = tab == selection
			val lift by animateDpAsState(if (active && tab != Tab.Enviar) (-4).dp else 0.dp, snappy(), label = "lift")
			val tilt by animateFloatAsState(if (active && tab != Tab.Enviar) -6f else 0f, snappy(), label = "tilt")
			val grow by animateFloatAsState(if (active) (if (tab == Tab.Enviar) 1.06f else 1.08f) else 1f, snappy(), label = "grow")
			Column(
				Modifier
					.weight(1f)
					.clickable(remember { MutableInteractionSource() }, indication = null, role = Role.Tab) {
						if (!active) haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
						onSelect(tab)
					}
					.semantics { selected = active; contentDescription = tab.label },
				horizontalAlignment = Alignment.CenterHorizontally,
				verticalArrangement = Arrangement.spacedBy(2.dp),
			) {
				if (tab == Tab.Enviar) {
					// same 38 dp slot as the other tabs (labels line up); the raised coin floats above it
					Box(Modifier.size(38.dp), contentAlignment = Alignment.Center) {
						Box(
							Modifier
								.requiredSize(56.dp)
								.offset(y = (-12).dp)
								.scale(grow)
								.drawBehind {
									// navy drop like the dock, then the coin with its darker gold band inside the bottom edge
									drawCircle(Palette.shadow, center = center + Offset(0f, 4.dp.toPx()))
									clipPath(Path().apply { addOval(Rect(Offset.Zero, size)) }) {
										drawRect(Palette.sunDark)
										drawCircle(Palette.sun, radius = size.minDimension / 2, center = center - Offset(0f, 4.dp.toPx()))
									}
								}
								.border(4.dp, Palette.surface, CircleShape),
							contentAlignment = Alignment.Center,
						) { Icon(tab.icon, Palette.onSun, size = 26.dp) }
					}
				} else {
					Box(
						Modifier
							.offset(y = lift)
							.rotate(tilt)
							.scale(grow)
							.size(38.dp)
							.tile(tab.color, Color.Black.copy(alpha = 0.18f), 14f, 3f),
						contentAlignment = Alignment.Center,
					) { Icon(tab.icon, Color.White, size = 22.dp) }
				}
				Text(tab.label, style = body(11, FontWeight.ExtraBold), color = if (active) Palette.ink else Palette.muted)
			}
		}
	}
}

@Composable
fun VSpace(h: Int) = Spacer(Modifier.size(h.dp))
