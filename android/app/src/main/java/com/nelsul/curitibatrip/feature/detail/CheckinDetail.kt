package com.nelsul.curitibatrip.feature.detail

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.CheckinDetail
import com.nelsul.curitibatrip.data.CheckinItem
import com.nelsul.curitibatrip.data.LikeBody
import com.nelsul.curitibatrip.data.LikeResponse
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.feature.feed.EmptyState
import com.nelsul.curitibatrip.feature.feed.LikeButton
import com.nelsul.curitibatrip.feature.feed.LikedBy
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.BackButton
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.ConfirmDialog
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TextEditDialog
import com.nelsul.curitibatrip.ui.components.TextLink
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.Radius
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import com.nelsul.curitibatrip.ui.theme.popIn
import kotlinx.coroutines.launch

/** Check-in page (web /c/:id): map picture, likes, note, comments, delete. */
@Composable
fun CheckinDetailScreen(id: String, contentPadding: PaddingValues, onBack: () -> Unit) {
	val app = LocalApp.current
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	var detail by remember { mutableStateOf<CheckinDetail?>(null) }
	var error by remember { mutableStateOf<String?>(null) }
	var editing by remember { mutableStateOf(false) }
	var confirmDelete by remember { mutableStateOf(false) }

	suspend fun load() {
		try { detail = Api.get("/api/checkins/$id"); error = null } catch (e: Exception) { app.handle(e); error = e.message }
	}
	LaunchedEffect(id) { load() }

	Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
		Column(Modifier.widthIn(max = 640.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
			BackButton(onBack)
			val d = detail
			when {
				d != null -> {
					val item = d.item
					val person = app.person(item.userId)
					val mine = item.userId == app.me?.id
					Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
						Avatar(person?.name ?: "?", person?.let { colorOf(it.color) } ?: Palette.muted, person?.photo, 44.dp)
						Column {
							Text("${person?.name ?: "Alguém"} fez check-in", style = display(19), color = Palette.ink)
							Text("${TripTime.longDay(TripTime.dayKey(item.at))}, ${TripTime.time(item.at)}", style = body(14), color = Palette.muted)
						}
					}
					val shape = RoundedCornerShape(Radius.card)
					Box(Modifier.popIn().fillMaxWidth().aspectRatio(1.5f).clip(shape).border(2.5.dp, Palette.line, shape).background(Palette.sea), contentAlignment = Alignment.Center) {
						if (item.snapshot != null) AsyncImage(item.snapshot, "Mapa do check-in", contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
						else Icon(IconName.Pin, Color.White, size = 40.dp)
					}
					Row(verticalAlignment = Alignment.CenterVertically) {
						LikeButton(d.likers.contains(app.me?.id)) { liked ->
							scope.launch {
								val me = app.me?.id ?: return@launch
								val before = d.likers
								detail = d.copy(likers = if (liked) before + me else before - me)
								try {
									val r: LikeResponse = Api.post("/api/likes", LikeBody(checkinId = id, liked = liked))
									detail = detail?.copy(likers = r.likers)
									app.feedChanged()
								} catch (e: Exception) { detail = detail?.copy(likers = before); app.handle(e) }
							}
						}
						Box(Modifier.weight(1f)) { LikedBy(d.likers) }
						TextLink("Google Maps", { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/maps/search/?api=1&query=${item.lat},${item.lng}"))) })
					}
					if (item.note.isNotEmpty()) {
						Text(item.note, style = body(17), color = Palette.ink, modifier = Modifier.fillMaxWidth().card(padding = 0.dp, radius = 18.dp).padding(horizontal = 14.dp, vertical = 10.dp))
					}
					if (mine) Row(verticalAlignment = Alignment.CenterVertically) {
						TextLink(if (item.note.isEmpty()) "Adicionar texto" else "Editar texto", { editing = true })
						Spacer(Modifier.weight(1f))
						ChunkyButton("Apagar check-in", { confirmDelete = true }, variant = ButtonVariant.Danger, small = true)
					}
					error?.let { Text(it, style = body(14, FontWeight.Bold), color = Palette.danger) }
					CommentsSection("/api/checkins/$id/comments", d.comments) { detail = detail?.copy(comments = it) }

					if (editing) TextEditDialog("Texto do check-in", item.note, { editing = false }) { text ->
						val updated: CheckinItem = Api.patch("/api/checkins/$id", mapOf("note" to text))
						detail = detail?.copy(item = updated)
						app.feedChanged()
					}
					if (confirmDelete) ConfirmDialog("Apagar este check-in? Os comentários e curtidas dele também somem.", "Apagar", { confirmDelete = false }) {
						scope.launch {
							try { Api.delete("/api/checkins/$id"); app.feedChanged(); onBack() } catch (e: Exception) { app.handle(e); error = e.message }
						}
					}
				}
				error != null -> EmptyState(error!!, retry = { scope.launch { load() } })
				else -> Box(Modifier.fillMaxWidth().padding(top = 80.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Palette.sea) }
			}
		}
	}
}
