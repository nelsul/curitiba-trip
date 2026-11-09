package com.nelsul.curitibatrip.feature.cotinha

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.Created
import com.nelsul.curitibatrip.data.Money
import com.nelsul.curitibatrip.data.NewSplit
import com.nelsul.curitibatrip.data.Ok
import com.nelsul.curitibatrip.data.PaidBody
import com.nelsul.curitibatrip.data.Split
import com.nelsul.curitibatrip.data.SplitList
import com.nelsul.curitibatrip.data.SplitShare
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.feature.feed.EmptyState
import com.nelsul.curitibatrip.ui.components.AppTextField
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.Chip
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.ConfirmDialog
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TitleRow
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** How many cotinhas I still owe (the dock's badge). */
object CotinhaBadge {
	var owing by mutableIntStateOf(0)
	fun update(splits: List<Split>, me: String?) {
		owing = splits.count { s -> s.payerId != me && s.shares.any { it.userId == me && it.paidAt == null } }
	}
	suspend fun refresh(me: String?) { runCatching { Api.get<SplitList>("/api/splits") }.getOrNull()?.let { update(it.splits, me) } }
}

/** Cotinha (web /cotinha): someone paid for the group, leaves their Pix key, and everyone marks when they paid. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CotinhaScreen(contentPadding: PaddingValues) {
	val app = LocalApp.current
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	var list by remember { mutableStateOf<SplitList?>(null) }
	var error by remember { mutableStateOf<String?>(null) }
	var showAll by remember { mutableStateOf(false) }
	var creating by remember { mutableStateOf(false) }
	var deleting by remember { mutableStateOf<Split?>(null) }
	var toast by remember { mutableStateOf<String?>(null) }
	var refreshing by remember { mutableStateOf(false) }
	val me = app.me?.id
	suspend fun load() {
		try {
			list = Api.get("/api/splits")
			error = null
			CotinhaBadge.update(list!!.splits, me)
		} catch (e: Exception) { app.handle(e); error = e.message }
	}
	LaunchedEffect(Unit) { load() }
	LaunchedEffect(toast) { if (toast != null) { delay(2500); toast = null } }
	val all = list?.splits ?: emptyList()
	val shown = all.filter { showAll || it.open }
	val iOwe = all.filter { it.payerId != me }.flatMap { it.shares }.filter { it.userId == me && it.paidAt == null }.sumOf { it.amountCents }
	val owedToMe = all.filter { it.payerId == me }.flatMap { it.shares }.filter { it.userId != me && it.paidAt == null }.sumOf { it.amountCents }

	Box(Modifier.fillMaxSize()) {
		PullToRefreshBox(refreshing, { scope.launch { refreshing = true; load(); refreshing = false } }, Modifier.fillMaxSize()) {
			Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
				Column(Modifier.widthIn(max = 640.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
					TitleRow(IconName.Wallet, "Cotinha")
					Text("Pagou algo para o grupo? Crie uma cotinha com sua chave Pix: cada um vê quanto deve e marca quando pagar.", style = body(16), color = Palette.muted)
					Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
						Total("Você deve", iOwe, Palette.coral, Modifier.weight(1f))
						Total("Te devem", owedToMe, Palette.leaf, Modifier.weight(1f))
					}
					ChunkyButton("Nova cotinha", { creating = true }, variant = ButtonVariant.Sun, fullWidth = true, icon = IconName.Plus)
					Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
						Chip(!showAll, { showAll = false }) { Text("Em aberto", style = body(15, FontWeight.ExtraBold)) }
						Chip(showAll, { showAll = true }) { Text("Todas", style = body(15, FontWeight.ExtraBold)) }
					}
					if (error != null && list == null) EmptyState(error!!, retry = { scope.launch { load() } })
					shown.forEach { s ->
						SplitCard(s,
							reload = { scope.launch { load() } },
							say = { toast = it },
							copy = {
								(context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Pix", s.pixKey))
								toast = "Chave Pix copiada!"
							},
							delete = { deleting = s })
					}
					if (list != null && shown.isEmpty()) Column(Modifier.fillMaxWidth().card(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
						Icon(IconName.Wallet, Palette.muted, size = 40.dp)
						Text(if (showAll) "Nenhuma cotinha ainda." else "Nenhuma cotinha em aberto.", style = body(16), color = Palette.muted)
					}
				}
			}
		}
		toast?.let {
			Text(it, style = body(14, FontWeight.ExtraBold), color = Palette.onLeaf,
				modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 130.dp).background(Palette.leaf, CircleShape).padding(horizontal = 16.dp, vertical = 8.dp))
		}
	}
	if (creating) NewSplitDialog(list?.myPix ?: "", onClose = { creating = false }) { scope.launch { load() } }
	deleting?.let { s ->
		ConfirmDialog("Apagar a cotinha \"${s.title}\"?", "Apagar", { deleting = null }) {
			deleting = null
			scope.launch { try { Api.delete("/api/splits/${s.id}"); load() } catch (e: Exception) { app.handle(e); toast = e.message } }
		}
	}
}

@Composable
private fun Total(label: String, cents: Int, color: Color, modifier: Modifier) {
	Column(modifier.card(12.dp)) {
		Text(label, style = body(14), color = Palette.ink)
		Text(Money.brl(cents), style = display(22), color = color)
	}
}

@Composable
private fun SplitCard(split: Split, reload: () -> Unit, say: (String) -> Unit, copy: () -> Unit, delete: () -> Unit) {
	val app = LocalApp.current
	val scope = rememberCoroutineScope()
	val me = app.me?.id
	val mine = split.payerId == me
	fun name(id: String) = if (id == me) "Você" else app.person(id)?.name ?: "Alguém"
	val payer = app.person(split.payerId)
	val paid = split.shares.count { it.paidAt != null }
	fun setPaid(userId: String, value: Boolean) = scope.launch {
		try { Api.post<PaidBody, Ok>("/api/splits/${split.id}/paid", PaidBody(userId, value)); reload() } catch (e: Exception) { app.handle(e); say(e.message ?: "") }
	}
	Column(Modifier.fillMaxWidth().alpha(if (split.open) 1f else 0.75f).card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
		Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
			Avatar(payer?.name ?: "?", colorOf(payer?.color), payer?.photo, 40.dp)
			Column(Modifier.weight(1f)) {
				Text(split.title, style = display(18), color = Palette.ink)
				Text("${if (mine) "Você pagou" else "${name(split.payerId)} pagou"} · ${TripTime.ago(split.createdAt)}", style = body(13), color = Palette.muted)
			}
			Text(Money.brl(split.totalCents), style = display(19), color = Palette.sun)
		}
		val myShare = split.shares.firstOrNull { it.userId == me }
		if (!mine && myShare != null) Row(
			Modifier.fillMaxWidth().background((if (myShare.paidAt != null) Palette.leaf else Palette.coral).copy(alpha = 0.22f), RoundedCornerShape(14.dp)).padding(horizontal = 12.dp, vertical = 8.dp),
			verticalAlignment = Alignment.CenterVertically,
		) {
			Text(if (myShare.paidAt != null) "Você já pagou" else "Sua parte", style = body(15, FontWeight.ExtraBold), color = Palette.ink, modifier = Modifier.weight(1f))
			Text(Money.brl(myShare.amountCents), style = display(19), color = Palette.ink)
		}
		if (split.pixKey.isNotEmpty()) Row(
			Modifier.fillMaxWidth().border(2.5.dp, Palette.sea, RoundedCornerShape(14.dp)).pressable(copy).padding(horizontal = 12.dp, vertical = 8.dp)
				.semantics { contentDescription = "Copiar a chave Pix ${split.pixKey}" },
			verticalAlignment = Alignment.CenterVertically,
		) {
			Column(Modifier.weight(1f)) {
				Text("${if (mine) "Sua chave Pix" else "Pix de ${name(split.payerId)}"} · toque para copiar", style = body(13), color = Palette.muted)
				Text(split.pixKey, style = body(16, FontWeight.ExtraBold), color = Palette.ink)
			}
			Icon(IconName.Copy, Palette.sea, size = 18.dp)
		}
		if (split.note.isNotEmpty()) Text(split.note, style = body(14), color = Palette.ink)
		Box(Modifier.fillMaxWidth().height(8.dp).background(Palette.track, CircleShape).semantics { contentDescription = "$paid de ${split.shares.size} pagaram" }) {
			Box(Modifier.fillMaxWidth(paid.toFloat() / maxOf(1, split.shares.size)).height(8.dp).background(Palette.leaf, CircleShape))
		}
		split.shares.forEach { x -> ShareRow(split, x, ::name) { setPaid(x.userId, x.paidAt == null) } }
		if (mine || app.me?.isAdmin == true) Row(verticalAlignment = Alignment.CenterVertically) {
			if (split.open && mine) ChunkyButton("Cobrar quem falta", {
				scope.launch {
					try { Api.post<Map<String, String>, Ok>("/api/splits/${split.id}/remind", emptyMap()); say("Lembrete enviado para quem ainda não pagou."); reload() }
					catch (e: Exception) { app.handle(e); say(e.message ?: "") }
				}
			}, variant = ButtonVariant.Secondary, small = true, icon = IconName.Bell)
			Spacer(Modifier.weight(1f))
			Text("Apagar", style = body(15, FontWeight.ExtraBold), color = Palette.danger, modifier = Modifier.pressable(delete).padding(10.dp))
		}
	}
}

@Composable
private fun ShareRow(split: Split, x: SplitShare, name: (String) -> String, toggle: () -> Unit) {
	val app = LocalApp.current
	val me = app.me?.id
	val p = app.person(x.userId)
	val canMark = x.userId == me || split.payerId == me || app.me?.isAdmin == true
	val ok = x.paidAt != null
	Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
		Avatar(p?.name ?: "?", colorOf(p?.color), p?.photo, 30.dp)
		Text(name(x.userId) + if (x.userId == split.payerId) " (pagou)" else "", style = body(15, FontWeight.Bold), color = Palette.ink, maxLines = 1, modifier = Modifier.weight(1f))
		Text(Money.brl(x.amountCents), style = body(15, FontWeight.ExtraBold), color = Palette.ink)
		val label = when {
			x.userId == split.payerId -> ""
			ok -> if (canMark) "Pago" else ""
			canMark -> if (x.userId == me) "Já paguei" else "Pagou?"
			else -> "Falta"
		}
		val button = canMark && x.userId != split.payerId
		Row(
			Modifier.widthIn(min = 84.dp).heightIn(min = 36.dp)
				.background(if (ok || x.userId == split.payerId) Palette.leaf else Palette.surface2, CircleShape)
				.border(2.dp, if (ok || x.userId == split.payerId) Palette.leaf else if (button) Palette.sea else Palette.line, CircleShape)
				.then(if (button) Modifier.pressable(toggle).semantics { contentDescription = if (ok) "Desmarcar pagamento de ${name(x.userId)}" else "Marcar que ${name(x.userId)} pagou" } else Modifier)
				.padding(horizontal = 10.dp),
			verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center,
		) {
			if (ok || x.userId == split.payerId) Icon(IconName.Check, Palette.onLeaf, size = 15.dp)
			if (label.isNotEmpty()) Text(" $label", style = body(13, FontWeight.ExtraBold), color = if (ok) Palette.onLeaf else if (button) Palette.ink else Palette.muted)
		}
	}
}

@Composable
private fun NewSplitDialog(myPix: String, onClose: () -> Unit, created: () -> Unit) {
	val app = LocalApp.current
	val scope = rememberCoroutineScope()
	var title by remember { mutableStateOf("") }
	var amount by remember { mutableStateOf("") }
	var pix by remember { mutableStateOf(myPix) }
	var note by remember { mutableStateOf("") }
	val who = remember { mutableStateListOf<String>().apply { addAll(app.people.map { it.id }) } }
	var busy by remember { mutableStateOf(false) }
	var error by remember { mutableStateOf<String?>(null) }
	val cents = Money.cents(amount)
	val parts = cents?.let { Money.parts(it, who.size) } ?: emptyList()

	Dialog(onClose, DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
		Column(Modifier.fillMaxSize().background(Palette.bg).systemBarsPadding().imePadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
			Row(verticalAlignment = Alignment.CenterVertically) {
				Text("Nova cotinha", style = display(22), color = Palette.ink, modifier = Modifier.weight(1f))
				Box(Modifier.heightIn(min = 44.dp).background(Palette.surface, CircleShape).pressable(onClose).padding(horizontal = 14.dp, vertical = 10.dp)) { Text("Cancelar", style = body(15, FontWeight.ExtraBold), color = Palette.ink) }
			}
			Label("O que foi"); AppTextField(title, { title = it }, "Ex.: Mercado, Uber do aeroporto", Modifier.fillMaxWidth(), singleLine = true)
			Label("Valor total (R$)"); AppTextField(amount, { amount = it }, "0,00", Modifier.fillMaxWidth(), singleLine = true, keyboard = KeyboardOptions(keyboardType = KeyboardType.Decimal))
			Label("Sua chave Pix"); AppTextField(pix, { pix = it }, "CPF, e-mail, celular ou chave aleatória", Modifier.fillMaxWidth(), singleLine = true)
			Label("Quem divide (${who.size})")
			app.people.forEach { p ->
				val i = who.indexOf(p.id)
				Row(
					Modifier.fillMaxWidth().heightIn(min = 48.dp).card(padding = 0.dp, radius = 14.dp).pressable({ if (i >= 0) who.remove(p.id) else who.add(p.id) }).padding(horizontal = 10.dp, vertical = 6.dp),
					verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
				) {
					Avatar(p.name, colorOf(p.color), p.photo, 30.dp)
					Text(if (p.id == app.me?.id) "Você" else p.name, style = body(16, FontWeight.Bold), color = Palette.ink, modifier = Modifier.weight(1f))
					if (i >= 0) {
						parts.getOrNull(i)?.let { Text(Money.brl(it), style = body(14, FontWeight.ExtraBold), color = Palette.leaf) }
						Icon(IconName.Check, Palette.leaf, size = 18.dp)
					}
				}
			}
			Label("Observação"); AppTextField(note, { note = it }, "Opcional", Modifier.fillMaxWidth())
			error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }
			ChunkyButton(if (busy) "Criando…" else "Criar e avisar", {
				when {
					title.isBlank() -> error = "Diga o que foi comprado."
					cents == null || cents <= 0 -> error = "Valor inválido."
					who.isEmpty() -> error = "Escolha quem divide."
					else -> scope.launch {
						busy = true
						try {
							Api.post<NewSplit, Created>("/api/splits", NewSplit(title, cents, pix, note, who.toList()))
							created(); onClose()
						} catch (e: Exception) { app.handle(e); error = e.message } finally { busy = false }
					}
				}
			}, variant = ButtonVariant.Sun, fullWidth = true, enabled = !busy)
		}
	}
}

@Composable
private fun Label(text: String) = Text(text, style = body(14, FontWeight.ExtraBold), color = Palette.ink)
