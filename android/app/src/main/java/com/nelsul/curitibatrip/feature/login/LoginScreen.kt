package com.nelsul.curitibatrip.feature.login

import android.os.Build
import android.provider.Settings
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.CodeResponse
import com.nelsul.curitibatrip.data.Person
import com.nelsul.curitibatrip.data.VerifyResponse
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TextLink
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import com.nelsul.curitibatrip.ui.theme.popIn
import kotlinx.coroutines.launch

/** Same flow as the web /login and iOS: passport card → "Quem é você?" → 6-digit code from the email. */
@Composable
fun LoginScreen() {
	val app = LocalApp.current
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	var people by remember { mutableStateOf<List<Person>>(emptyList()) }
	var picked by remember { mutableStateOf<Person?>(null) }
	var maskedEmail by remember { mutableStateOf("") }
	var code by remember { mutableStateOf("") }
	var busy by remember { mutableStateOf<String?>(null) }
	var error by remember { mutableStateOf<String?>(null) }

	LaunchedEffect(Unit) {
		runCatching { Api.get<List<Person>>("/api/auth/people") }.onSuccess { people = it }.onFailure { error = it.message }
	}

	fun sendCode(p: Person) = scope.launch {
		busy = p.id
		error = null
		try {
			val r: CodeResponse = Api.post("/api/auth/code", mapOf("userId" to p.id))
			maskedEmail = r.maskedEmail
			picked = p
		} catch (e: Exception) {
			error = e.message
		} finally { busy = null }
	}

	fun verify(p: Person) = scope.launch {
		if (busy != null || code.length != 6) return@launch
		busy = "code"
		error = null
		try {
			val device = Settings.Global.getString(context.contentResolver, "device_name") ?: "${Build.MANUFACTURER} ${Build.MODEL}"
			val r: VerifyResponse = Api.post("/api/auth/verify", mapOf("userId" to p.id, "code" to code, "deviceName" to device))
			app.signedIn(r)
		} catch (e: Exception) {
			error = e.message
			code = ""
		} finally { busy = null }
	}

	Column(
		Modifier
			.fillMaxSize()
			.safeDrawingPadding()
			.imePadding()
			.verticalScroll(rememberScrollState())
			.padding(horizontal = 16.dp, vertical = 24.dp),
		horizontalAlignment = Alignment.CenterHorizontally,
	) {
		Column(Modifier.widthIn(max = 440.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
			// on the code step the passport shrinks so the field and button stay above the keyboard
			PassportCard(compact = picked != null)
			AnimatedContent(picked, label = "step") { p ->
				if (p == null) {
					Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
						Text("Fotos, vídeos e lugares de todo mundo, num diário só.", style = body(15, FontWeight.Bold), color = Palette.muted, textAlign = TextAlign.Center)
						Text("Quem é você?", style = display(24), color = Palette.ink)
						error?.let { Text(it, style = body(15, FontWeight.Bold), color = Palette.danger, textAlign = TextAlign.Center) }
						if (people.isEmpty() && error == null) CircularProgressIndicator(color = Palette.sea, modifier = Modifier.padding(16.dp))
						PeopleGrid(people, busy) { sendCode(it) }
						Text("Vamos mandar um código para o seu e-mail.", style = body(13), color = Palette.muted)
					}
				} else {
					CodeStep(p, maskedEmail, code, busy, error,
						onCode = { v ->
							code = v.filter(Char::isDigit).take(6)
							if (code.length == 6) verify(p)
						},
						onVerify = { verify(p) },
						onResend = { sendCode(p) },
						onSwitch = { picked = null; code = ""; error = null })
				}
			}
		}
	}
}

@Composable
private fun PeopleGrid(people: List<Person>, busy: String?, onPick: (Person) -> Unit) {
	BoxWithConstraints(Modifier.fillMaxWidth()) {
		val cols = maxOf(1, ((maxWidth.value + 12) / (96 + 12)).toInt())
		Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
			people.chunked(cols).forEachIndexed { row, chunk ->
				Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
					chunk.forEachIndexed { i, p ->
						Column(
							Modifier
								.weight(1f)
								.popIn(((row * cols + i) * 60).toLong())
								.pressable({ onPick(p) }, enabled = busy == null)
								.card(padding = 0.dp, radius = 20.dp)
								.padding(vertical = 14.dp, horizontal = 4.dp),
							horizontalAlignment = Alignment.CenterHorizontally,
							verticalArrangement = Arrangement.spacedBy(6.dp),
						) {
							Avatar(p.name, colorOf(p.color), p.photo, 64.dp)
							Text(p.name, style = display(17), color = Palette.ink, maxLines = 1)
							if (busy == p.id) Text("Enviando…", style = body(12, FontWeight.ExtraBold), color = Palette.muted)
						}
					}
					repeat(cols - chunk.size) { Spacer(Modifier.weight(1f)) }
				}
			}
		}
	}
}

@Composable
private fun CodeStep(
	p: Person, maskedEmail: String, code: String, busy: String?, error: String?,
	onCode: (String) -> Unit, onVerify: () -> Unit, onResend: () -> Unit, onSwitch: () -> Unit,
) {
	val focus = remember { FocusRequester() }
	var focused by remember { mutableStateOf(false) }
	LaunchedEffect(Unit) { focus.requestFocus() }
	Column(Modifier.popIn().card(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
		Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
			Avatar(p.name, colorOf(p.color), p.photo, 56.dp)
			Text(buildAnnotatedString {
				append("Oi, ${p.name}! Enviamos um código de 6 números para ")
				withStyle(SpanStyle(fontWeight = FontWeight.ExtraBold)) { append(maskedEmail) }
				append(".")
			}, style = body(16), color = Palette.ink)
		}
		Text("Código", style = display(16), color = Palette.ink)
		BasicTextField(
			value = code,
			onValueChange = onCode,
			singleLine = true,
			keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
			textStyle = display(30).copy(color = Palette.ink, textAlign = TextAlign.Center, letterSpacing = 10.sp),
			cursorBrush = SolidColor(Palette.sea),
			modifier = Modifier
				.fillMaxWidth()
				.focusRequester(focus)
				.onFocusChanged { focused = it.isFocused }
				.background(Palette.surface, RoundedCornerShape(16.dp))
				.border(2.5.dp, if (focused) Palette.sea else Palette.line, RoundedCornerShape(16.dp))
				.padding(vertical = 10.dp)
				.semantics { contentDescription = "Código de 6 números" },
		)
		error?.let { Text(it, style = body(15, FontWeight.Bold), color = Palette.danger) }
		ChunkyButton(if (busy == "code") "Embarcando…" else "Embarcar", onVerify, variant = ButtonVariant.Sun, fullWidth = true, enabled = code.length == 6 && busy == null)
		Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
			TextLink("Não chegou? Enviar de novo", onResend)
			Text("Olhe também a caixa de spam.", style = body(13), color = Palette.muted)
			TextLink("Não é você? Trocar", onSwitch)
		}
	}
}

/** The teal passport cover with drifting clouds and a plane crossing the top edge. */
@Composable
fun PassportCard(compact: Boolean) {
	val t = rememberInfiniteTransition(label = "passport")
	val fly by t.animateFloat(0f, 1f, infiniteRepeatable(tween(7000, easing = LinearEasing)), label = "fly")
	val drift by t.animateFloat(0f, 1f, infiniteRepeatable(tween(6000), RepeatMode.Reverse), label = "drift")
	BoxWithConstraints(
		Modifier
			.popIn()
			.fillMaxWidth()
			.drawBehind {
				val r = CornerRadius(26.dp.toPx())
				drawRoundRect(Palette.passportEdge, topLeft = Offset(0f, 6.dp.toPx()), size = size, cornerRadius = r)
			}
			.clip(RoundedCornerShape(26.dp))
			.drawBehind {
				drawRect(Brush.radialGradient(listOf(Palette.passportLight, Palette.passport), center = Offset(size.width * 0.3f, size.height * 0.2f), radius = size.width))
			}
			.drawBehind {
				// clouds stay in the corners, behind the text
				val cloud = Color.White.copy(alpha = 0.14f)
				drawRoundRect(cloud, Offset(size.width * 0.75f + drift * 14.dp.toPx(), 22.dp.toPx()), Size(60.dp.toPx(), 18.dp.toPx()), CornerRadius(9.dp.toPx()))
				if (!compact) {
					drawRoundRect(cloud, Offset(size.width * 0.09f + drift * 10.dp.toPx(), size.height - 48.dp.toPx()), Size(74.dp.toPx(), 18.dp.toPx()), CornerRadius(9.dp.toPx()))
					drawRoundRect(cloud, Offset(size.width * 0.80f - drift * 8.dp.toPx(), size.height - 70.dp.toPx()), Size(46.dp.toPx(), 18.dp.toPx()), CornerRadius(9.dp.toPx()))
				}
				val w = 2.dp.toPx(); val inset = 10.dp.toPx()
				drawRoundRect(Palette.onPassport.copy(alpha = 0.45f), Offset(inset, inset), Size(size.width - 2 * inset, size.height - 2 * inset), CornerRadius(18.dp.toPx()),
					style = Stroke(w, pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 5.dp.toPx()))))
				val b = 3.dp.toPx()
				drawRoundRect(Palette.passportEdge, Offset(b / 2, b / 2), Size(size.width - b, size.height - b), CornerRadius(26.dp.toPx()), style = Stroke(b))
			}
			.semantics(mergeDescendants = true) { contentDescription = "Passaporte da viagem: Curitiba, 11 a 18 de novembro de 2026" },
	) {
		val width = maxWidth
		Icon(IconName.Plane, Color.White.copy(alpha = 0.9f), Modifier.offset(x = -40.dp + (width + 80.dp) * fly, y = 6.dp).rotate(90f), size = 24.dp)
		Column(
			Modifier.fillMaxWidth().padding(vertical = if (compact) 22.dp else 34.dp),
			horizontalAlignment = Alignment.CenterHorizontally,
			verticalArrangement = Arrangement.spacedBy(4.dp),
		) {
			Text("PASSAPORTE DA VIAGEM", style = body(12, FontWeight.ExtraBold).copy(letterSpacing = 2.4.sp), color = Palette.onPassport.copy(alpha = 0.9f))
			Text("Curitiba", style = display(if (compact) 32 else 48).copy(shadow = Shadow(Color.Black.copy(alpha = 0.15f), Offset(0f, 6f), 0f)), color = Palette.onPassport)
			Text("11 – 18 de novembro · 2026", style = body(if (compact) 14 else 16, FontWeight.Bold), color = Palette.onPassport)
			if (!compact) {
				Box(
					Modifier
						.padding(top = 14.dp)
						.rotate(-4f + 8f * drift)
						.size(58.dp)
						.drawBehind {
							drawCircle(Palette.sunDark, center = center + Offset(0f, 4.dp.toPx()))
							drawCircle(Palette.sun)
						},
					contentAlignment = Alignment.Center,
				) { Icon(IconName.Leaf, Palette.onSun, size = 30.dp) }
			}
		}
	}
}
