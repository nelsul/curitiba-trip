package com.nelsul.curitibatrip.feature.feed

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.nelsul.curitibatrip.AppState
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.FeedPage
import com.nelsul.curitibatrip.data.Post
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.DaySign
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TitleRow
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import kotlinx.coroutines.launch

/** Pages through GET /api/feed (newest first, carousels already grouped by the server). */
class FeedModel {
	var posts by mutableStateOf<List<Post>>(emptyList())
		private set
	var loading by mutableStateOf(false)
		private set
	var error by mutableStateOf<String?>(null)
		private set
	private var cursor: String? = null
	private var reachedEnd = false

	suspend fun refresh(app: AppState) {
		cursor = null
		reachedEnd = false
		load(app, replace = true)
	}

	suspend fun loadMore(app: AppState) {
		if (reachedEnd || loading) return
		load(app, replace = false)
	}

	private suspend fun load(app: AppState, replace: Boolean) {
		loading = true
		try {
			val page: FeedPage = Api.get("/api/feed", mapOf("limit" to "20", "before" to if (replace) null else cursor))
			posts = if (replace) page.posts else posts + page.posts.filter { p -> posts.none { it.key == p.key } }
			cursor = page.nextCursor
			reachedEnd = page.nextCursor == null
			error = null
		} catch (e: Exception) {
			app.handle(e)
			error = e.message
		} finally {
			loading = false
		}
	}
}

/** Diário: Instagram-style feed under wooden day signs, newest first (same as the web and iOS). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedScreen(contentPadding: PaddingValues, open: Opener) {
	val app = LocalApp.current
	val model = remember { FeedModel() }
	val scope = rememberCoroutineScope()
	val list = rememberLazyListState()
	var refreshing by remember { mutableStateOf(false) }

	LaunchedEffect(app.feedVersion) { model.refresh(app) }
	// load the next page when the last post comes into view
	val nearEnd by remember { derivedStateOf { list.layoutInfo.visibleItemsInfo.lastOrNull()?.index?.let { it >= list.layoutInfo.totalItemsCount - 2 } ?: false } }
	LaunchedEffect(Unit) { snapshotFlow { nearEnd }.collect { if (it && model.posts.isNotEmpty()) model.loadMore(app) } }

	PullToRefreshBox(
		isRefreshing = refreshing,
		onRefresh = { scope.launch { refreshing = true; model.refresh(app); refreshing = false } },
		modifier = Modifier.fillMaxSize(),
	) {
		LazyColumn(
			state = list,
			contentPadding = contentPadding,
			horizontalAlignment = Alignment.CenterHorizontally,
			verticalArrangement = Arrangement.spacedBy(22.dp),
			modifier = Modifier.fillMaxSize(),
		) {
			item(key = "title") {
				TitleRow(IconName.Journal, "Diário da viagem", Modifier.widthIn(max = 600.dp).fillMaxWidth().padding(start = 16.dp, top = 12.dp))
			}
			if (model.posts.isEmpty()) {
				item(key = "empty") {
					val error = model.error
					when {
						error != null -> EmptyState(error, retry = { scope.launch { model.refresh(app) } })
						!model.loading -> EmptyState("Nada por aqui ainda. Que tal registrar o primeiro momento?")
					}
				}
			}
			itemsIndexed(model.posts, key = { _, p -> p.key }) { i, post ->
				Column(Modifier.widthIn(max = 600.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(22.dp)) {
					if (i == 0 || model.posts[i - 1].day != post.day) {
						DaySign(TripTime.longDay(post.day), Modifier.padding(top = if (i == 0) 0.dp else 8.dp))
					}
					val person = app.person(post.userId)
					if (post.type == "checkin" && post.item != null) CheckinPost(post.item, person, open)
					else if (post.items.isNotEmpty()) MediaPost(post.items, person, open)
				}
			}
			if (model.loading && !refreshing) item(key = "loading") { CircularProgressIndicator(color = Palette.sea, modifier = Modifier.padding(16.dp)) }
		}
	}
}

@Composable
fun EmptyState(text: String, retry: (() -> Unit)? = null) {
	Column(
		Modifier.padding(horizontal = 16.dp).fillMaxWidth().card(24.dp),
		horizontalAlignment = Alignment.CenterHorizontally,
		verticalArrangement = Arrangement.spacedBy(12.dp),
	) {
		Icon(IconName.Island, Palette.sea, size = 56.dp)
		Text(text, style = body(16), color = Palette.ink, textAlign = TextAlign.Center)
		if (retry != null) ChunkyButton("Tentar de novo", retry, variant = ButtonVariant.Sea, small = true)
	}
}
