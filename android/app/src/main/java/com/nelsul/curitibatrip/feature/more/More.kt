package com.nelsul.curitibatrip.feature.more

import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.Device
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TitleRow
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject

/** Mais (web /mais): profile photo (circle framer), devices, admin link, sign out. */
@Composable
fun MoreScreen(contentPadding: PaddingValues) {
	val app = LocalApp.current
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	var devices by remember { mutableStateOf<List<Device>>(emptyList()) }
	var cropping by remember { mutableStateOf<Bitmap?>(null) }
	var savingPhoto by remember { mutableStateOf(false) }
	var error by remember { mutableStateOf<String?>(null) }

	suspend fun loadDevices() { runCatching { Api.get<List<Device>>("/api/devices") }.getOrNull()?.let { devices = it } }
	LaunchedEffect(Unit) { loadDevices() }

	// the system photo picker: no storage permission needed
	val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
		if (uri != null) scope.launch {
			val bmp = withContext(Dispatchers.IO) { loadForCrop(context, uri) }
			if (bmp != null) cropping = bmp else error = "Não foi possível abrir essa imagem."
		}
	}

	Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
		Column(Modifier.widthIn(max = 640.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
			TitleRow(IconName.User, "Mais")
			app.me?.let { me ->
				Row(Modifier.fillMaxWidth().card(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
					val wobble by rememberInfiniteTransition(label = "saving").animateFloat(-8f, 8f, infiniteRepeatable(tween(250), RepeatMode.Reverse), label = "w")
					Box(
						Modifier
							.pressable({ picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) })
							.semantics { contentDescription = "Trocar a minha foto" },
					) {
						Avatar(me.name, colorOf(me.color), me.photo, 88.dp)
						Box(
							Modifier
								.align(Alignment.BottomEnd)
								.offset(4.dp, 4.dp)
								.rotate(if (savingPhoto) wobble else 0f)
								.size(32.dp)
								.background(Palette.sun, CircleShape)
								.border(3.dp, Palette.surface, CircleShape),
							contentAlignment = Alignment.Center,
						) { Icon(IconName.Camera, Palette.onSun, size = 16.dp) }
					}
					Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
						Text(me.name, style = display(26), color = Palette.ink)
						if (me.isAdmin) Text("Administrador", style = body(14), color = Palette.muted)
						Text("Toque na foto para trocar.", style = body(14), color = Palette.muted)
					}
				}
			}
			error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }

			Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
				Text("Aparelhos conectados", style = display(20), color = Palette.ink)
				devices.forEach { d ->
					Row(verticalAlignment = Alignment.CenterVertically) {
						Column(Modifier.weight(1f)) {
							Text((d.deviceName ?: "Celular") + if (d.current) " (este)" else "", style = body(16, FontWeight.Bold), color = Palette.ink)
							d.lastUsedAt?.let { Text("Usado ${TripTime.ago(it)}", style = body(13), color = Palette.muted) }
						}
						if (!d.current) ChunkyButton("Sair", {
							scope.launch {
								try { Api.delete("/api/devices/${d.id}"); loadDevices() } catch (e: Exception) { error = e.message }
							}
						}, variant = ButtonVariant.Danger, small = true)
					}
				}
				if (devices.isEmpty()) Text("Só este celular.", style = body(14), color = Palette.muted)
			}

			if (app.me?.isAdmin == true) {
				ChunkyButton("Gerenciar pessoas (site)", { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(Api.base + "/admin"))) }, variant = ButtonVariant.Secondary, fullWidth = true)
			}
			ChunkyButton("Sair", { scope.launch { app.signOut() } }, variant = ButtonVariant.Secondary, fullWidth = true)
		}
	}

	cropping?.let { bmp ->
		AvatarCropper(bmp, onDone = { jpeg ->
			cropping = null
			val me = app.me ?: return@AvatarCropper
			scope.launch {
				savingPhoto = true
				try {
					Api.put<JsonObject>("/api/users/${me.id}/avatar", jpeg, "image/jpeg")
					app.reloadMe()
					app.feedChanged()
					error = null
				} catch (e: Exception) { app.handle(e); error = e.message } finally { savingPhoto = false }
			}
		}, onCancel = { cropping = null })
	}
}
