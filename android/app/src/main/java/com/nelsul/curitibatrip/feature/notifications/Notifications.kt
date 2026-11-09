package com.nelsul.curitibatrip.feature.notifications

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.Ok
import com.nelsul.curitibatrip.data.Route
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.data.TokenStore
import com.nelsul.curitibatrip.feature.feed.EmptyState
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TitleRow
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/** GET /api/notifications: the last two weeks of what the group did that concerns me (texts come ready from the server). */
@Serializable
data class NoteItem(
	val id: String,
	val kind: String, // post | checkin | comment | like | mention | split | paid
	val userId: String,
	val text: String,
	val body: String = "",
	val at: String,
	val mediaId: String? = null,
	val checkinId: String? = null,
	val cotinha: Boolean = false,
	val image: String? = null,
	val unread: Boolean = false,
)
@Serializable data class NoteList(val items: List<NoteItem> = emptyList(), val unread: Int = 0)
@Serializable data class UnreadCount(val unread: Int = 0)

/** The bell's red count. */
object NotificationsBadge {
	var unread by mutableIntStateOf(0)
	suspend fun refresh() {
		if (TokenStore.token == null) return
		runCatching { Api.get<UnreadCount>("/api/notifications", mapOf("count" to "1")) }.getOrNull()?.let { unread = it.unread }
	}
}

private val icons = mapOf(
	"post" to (IconName.Camera to Palette.sea), "checkin" to (IconName.Pin to Palette.leaf), "comment" to (IconName.Chat to Palette.sky),
	"like" to (IconName.Heart to Palette.berry), "mention" to (IconName.Chat to Palette.plum), "split" to (IconName.Wallet to Palette.sun),
	"paid" to (IconName.Check to Palette.leaf),
)

/** Notificações (the bell next to "Enviar"): posts, check-ins, comments and likes on my posts, mentions and cotinhas. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(contentPadding: PaddingValues, open: (Route?) -> Unit) {
	val app = LocalApp.current
	val scope = rememberCoroutineScope()
	var list by remember { mutableStateOf<NoteList?>(null) }
	var error by remember { mutableStateOf<String?>(null) }
	var refreshing by remember { mutableStateOf(false) }
	suspend fun load() {
		try {
			list = Api.get("/api/notifications")
			error = null
			// opening the page reads everything
			NotificationsBadge.unread = 0
			runCatching { Api.post<Map<String, String>, Ok>("/api/notifications/seen", emptyMap()) }
		} catch (e: Exception) { app.handle(e); error = e.message }
	}
	LaunchedEffect(Unit) { load() }

	PullToRefreshBox(refreshing, { scope.launch { refreshing = true; load(); refreshing = false } }, Modifier.fillMaxSize()) {
		Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
			Column(Modifier.widthIn(max = 640.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
				TitleRow(IconName.Bell, "Notificações")
				Text("O que o grupo fez nos últimos 14 dias: posts, check-ins, comentários e curtidas nos seus posts, quando te marcam e as cotinhas.",
					style = body(14), color = Palette.muted)
				val l = list
				when {
					l == null && error != null -> EmptyState(error!!, retry = { scope.launch { load() } })
					l == null -> CircularProgressIndicator(color = Palette.sea, modifier = Modifier.align(Alignment.CenterHorizontally).padding(16.dp))
					l.items.isEmpty() -> Column(Modifier.fillMaxWidth().card(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
						Icon(IconName.Bell, Palette.muted, size = 40.dp)
						Text("Nada por aqui ainda.", style = body(16), color = Palette.muted)
					}
					else -> l.items.forEach { n ->
						NoteRow(n) {
							if (n.cotinha) open(null)
							else (n.mediaId?.let { Route.Media(it) } ?: n.checkinId?.let { Route.Checkin(it) })?.let { open(it) }
						}
					}
				}
			}
		}
	}
}

@Composable
private fun NoteRow(n: NoteItem, onClick: () -> Unit) {
	val app = LocalApp.current
	val p = app.person(n.userId)
	val (icon, color) = icons[n.kind] ?: (IconName.Bell to Palette.sea)
	val shape = RoundedCornerShape(18.dp)
	Row(
		Modifier.fillMaxWidth().background(if (n.unread) Palette.sea.copy(alpha = 0.12f) else Palette.surface, shape)
			.border(2.5.dp, if (n.unread) Palette.sea else Palette.line, shape).pressable(onClick).padding(10.dp)
			.semantics(mergeDescendants = true) { if (n.unread) contentDescription = "Nova: ${n.text}" },
		verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
	) {
		Box {
			Avatar(p?.name ?: "?", colorOf(p?.color), p?.photo, 44.dp)
			Box(Modifier.align(Alignment.BottomEnd).offset(x = 4.dp, y = 4.dp).size(22.dp).background(color, CircleShape).border(2.dp, Palette.surface, CircleShape),
				contentAlignment = Alignment.Center) { Icon(icon, Color.White, size = 12.dp) }
		}
		Column(Modifier.weight(1f)) {
			Text(n.text, style = body(15, FontWeight.ExtraBold), color = Palette.ink)
			if (n.body.isNotEmpty()) Text(n.body, style = body(13), color = Palette.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
			Text(TripTime.ago(n.at), style = body(12), color = Palette.muted)
		}
		n.image?.let { AsyncImage(it, null, contentScale = ContentScale.Crop, modifier = Modifier.size(48.dp).clip(RoundedCornerShape(10.dp))) }
		if (n.unread) Box(Modifier.size(9.dp).background(Palette.coral, CircleShape))
	}
}
