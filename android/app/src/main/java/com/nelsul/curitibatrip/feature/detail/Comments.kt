package com.nelsul.curitibatrip.feature.detail

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.Comment
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.ui.components.AppTextField
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import com.nelsul.curitibatrip.ui.theme.popIn
import kotlinx.coroutines.launch

/** Speech-bubble comments + composer, for a photo/video or a check-in (same as the web and iOS). */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun CommentsSection(path: String, comments: List<Comment>, onChange: (List<Comment>) -> Unit) {
	val app = LocalApp.current
	val scope = rememberCoroutineScope()
	val focus = LocalFocusManager.current
	val haptics = LocalHapticFeedback.current
	var draft by remember { mutableStateOf("") }
	var sending by remember { mutableStateOf(false) }
	var error by remember { mutableStateOf<String?>(null) }
	var menuFor by remember { mutableStateOf<String?>(null) }

	Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
		Row(Modifier.semantics(mergeDescendants = true) { heading() }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
			Icon(IconName.Chat, Palette.ink)
			Text("Comentários", style = display(22), color = Palette.ink)
		}
		if (comments.isEmpty()) Text("Ninguém comentou ainda.", style = body(15), color = Palette.muted)
		comments.forEach { c ->
			Row(Modifier.popIn(), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
				Avatar(c.name, colorOf(c.color), c.photo, 34.dp)
				Column(
					Modifier
						.weight(1f)
						.bubble()
						.combinedClickable(onClick = {}, onLongClick = {
							if (c.userId == app.me?.id) { haptics.performHapticFeedback(HapticFeedbackType.LongPress); menuFor = c.id }
						})
						.padding(horizontal = 12.dp, vertical = 8.dp),
				) {
					Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
						Text(c.name, style = display(15), color = Palette.ink)
						Text(TripTime.ago(c.at), style = body(12), color = Palette.muted)
					}
					Text(c.body, style = body(16), color = Palette.ink)
					DropdownMenu(menuFor == c.id, { menuFor = null }) {
						DropdownMenuItem(text = { Text("Apagar comentário", color = Palette.danger) }, onClick = {
							menuFor = null
							scope.launch {
								try {
									Api.delete("/api/comments/${c.id}")
									onChange(comments - c)
									app.feedChanged()
								} catch (e: Exception) { app.handle(e); error = e.message }
							}
						})
					}
				}
			}
		}
		Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
			AppTextField(draft, { draft = it }, "Escreva um comentário…", Modifier.weight(1f))
			ChunkyButton(if (sending) "…" else "Comentar", {
				scope.launch {
					sending = true
					try {
						val c: Comment = Api.post(path, mapOf("body" to draft.trim()))
						onChange(comments + c)
						draft = ""
						focus.clearFocus()
						error = null
						app.feedChanged()
					} catch (e: Exception) { app.handle(e); error = e.message } finally { sending = false }
				}
			}, variant = ButtonVariant.Sea, small = true, enabled = !sending && draft.isNotBlank())
		}
		error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }
	}
}

/** Rounded speech bubble with a little tail on the left (web `.say`). */
private fun Modifier.bubble() = drawBehind {
	val r = 18.dp.toPx()
	val path = Path().apply {
		addRoundRect(RoundRect(0f, 0f, size.width, size.height, CornerRadius(r)))
		moveTo(1f, 12.dp.toPx()); lineTo(-8.dp.toPx(), 19.dp.toPx()); lineTo(1f, 26.dp.toPx()); close()
	}
	drawPath(path, Palette.surface)
	drawPath(path, Palette.line, style = Stroke(2.5.dp.toPx()))
}
