package com.nelsul.curitibatrip.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import com.nelsul.curitibatrip.ui.theme.popIn
import kotlinx.coroutines.launch

/** The round "‹" back button at the top of pushed pages. */
@Composable
fun BackButton(onBack: () -> Unit, modifier: Modifier = Modifier) {
	Box(
		modifier
			.size(44.dp)
			.pressable(onBack)
			.background(Palette.surface, CircleShape)
			.border(2.5.dp, Palette.line, CircleShape)
			.semantics { contentDescription = "Voltar" },
		contentAlignment = Alignment.Center,
	) { Text("‹", style = display(30), color = Palette.ink, modifier = Modifier.padding(bottom = 4.dp, end = 2.dp)) }
}

/** The app's text box: surface fill, 2.5 dp border that turns sea-blue while focused. */
@Composable
fun AppTextField(
	value: String,
	onValueChange: (String) -> Unit,
	placeholder: String,
	modifier: Modifier = Modifier,
	singleLine: Boolean = false,
	minLines: Int = 1,
	focusRequester: FocusRequester? = null,
) {
	var focused by remember { mutableStateOf(false) }
	BasicTextField(
		value = value,
		onValueChange = onValueChange,
		singleLine = singleLine,
		minLines = minLines,
		maxLines = if (singleLine) 1 else 6,
		textStyle = body(16).copy(color = Palette.ink),
		cursorBrush = SolidColor(Palette.sea),
		modifier = modifier
			.then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
			.onFocusChanged { focused = it.isFocused },
		decorationBox = { inner ->
			Box(
				Modifier
					.background(Palette.surface2, RoundedCornerShape(16.dp))
					.border(2.5.dp, if (focused) Palette.sea else Palette.line, RoundedCornerShape(16.dp))
					.padding(horizontal = 14.dp, vertical = 10.dp),
			) {
				if (value.isEmpty()) Text(placeholder, style = body(16), color = Palette.muted)
				inner()
			}
		},
	)
}

/** A card dialog that pops in (Material dialogs look out of place in this design). */
@Composable
fun CardDialog(onDismiss: () -> Unit, content: @Composable () -> Unit) {
	Dialog(onDismissRequest = onDismiss) {
		Column(Modifier.widthIn(max = 440.dp).fillMaxWidth().popIn().card(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) { content() }
	}
}

/** Edit a caption or note; `save` throws to show its message. */
@Composable
fun TextEditDialog(title: String, initial: String, onDismiss: () -> Unit, save: suspend (String) -> Unit) {
	var text by remember { mutableStateOf(initial) }
	var busy by remember { mutableStateOf(false) }
	var error by remember { mutableStateOf<String?>(null) }
	val scope = rememberCoroutineScope()
	val focus = remember { FocusRequester() }
	LaunchedEffect(Unit) { focus.requestFocus() }
	CardDialog(onDismiss) {
		Text(title, style = display(22), color = Palette.ink)
		AppTextField(text, { text = it }, "Escreva aqui…", Modifier.fillMaxWidth().heightIn(min = 96.dp), minLines = 3, focusRequester = focus)
		error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }
		Row(verticalAlignment = Alignment.CenterVertically) {
			ChunkyButton("Cancelar", onDismiss, variant = ButtonVariant.Secondary, small = true)
			Spacer(Modifier.weight(1f))
			ChunkyButton(if (busy) "Salvando…" else "Salvar", {
				scope.launch {
					busy = true
					try { save(text.trim()); onDismiss() } catch (e: Exception) { error = e.message } finally { busy = false }
				}
			}, variant = ButtonVariant.Sun, small = true, enabled = !busy)
		}
	}
}

/** "Apagar …? Não dá para desfazer." */
@Composable
fun ConfirmDialog(text: String, action: String, onDismiss: () -> Unit, onConfirm: () -> Unit) {
	CardDialog(onDismiss) {
		Text(text, style = body(17), color = Palette.ink)
		Row(verticalAlignment = Alignment.CenterVertically) {
			ChunkyButton("Cancelar", onDismiss, variant = ButtonVariant.Secondary, small = true)
			Spacer(Modifier.weight(1f))
			ChunkyButton(action, { onDismiss(); onConfirm() }, variant = ButtonVariant.Danger, small = true)
		}
	}
}
