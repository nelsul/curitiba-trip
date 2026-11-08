package com.nelsul.curitibatrip.feature.shell

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.imePadding
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import com.nelsul.curitibatrip.data.Route
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.feature.enviar.EnviarScreen
import com.nelsul.curitibatrip.feature.galeria.GaleriaScreen
import com.nelsul.curitibatrip.feature.mapa.MapaScreen
import com.nelsul.curitibatrip.background.BackgroundLocation
import com.nelsul.curitibatrip.background.Notifier
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import com.nelsul.curitibatrip.data.LocationSharing
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.nelsul.curitibatrip.upload.Uploads
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import com.nelsul.curitibatrip.feature.detail.CheckinDetailScreen
import com.nelsul.curitibatrip.feature.detail.MediaDetailScreen
import com.nelsul.curitibatrip.feature.more.MoreScreen
import com.nelsul.curitibatrip.feature.roteiro.RoteiroScreen
import com.nelsul.curitibatrip.ui.components.DottedBackground
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.feature.feed.FeedScreen
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.Dock
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.Tab
import com.nelsul.curitibatrip.ui.components.TitleRow
import com.nelsul.curitibatrip.ui.components.TopBar
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.popIn

/** Room under every list for the floating dock. */
val DockSpace = PaddingValues(bottom = 112.dp)

/** Top bar + the screen for the selected tab + the floating dock. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun Shell() {
	var tab by rememberSaveable { mutableStateOf(Tab.Diario) }
	val context = LocalContext.current
	val openWeb: (String) -> Unit = { path -> context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(Api.base + path))) }
	// each tab keeps its own stack of pages (photo/check-in) on top of its main screen
	val stacks = remember { Tab.entries.associateWith { mutableStateListOf<Route>() } }
	val stack = stacks.getValue(tab)
	val open: (Route) -> Unit = { stack.add(it) }
	val back: () -> Unit = { if (stack.isNotEmpty()) stack.removeAt(stack.lastIndex) }
	BackHandler(enabled = stack.isNotEmpty(), onBack = back)
	BackHandler(enabled = stack.isEmpty() && tab != Tab.Diario) { tab = Tab.Diario }
	// live sharing runs only while the app is open; leaving the app marks what's there as seen
	LifecycleResumeEffect(Unit) {
		LocationSharing.resume()
		onPauseOrDispose { LocationSharing.pause(); Notifier.markSeen(context) }
	}
	// background check, reminders and (if on) background location; ask once for notifications
	val notifyPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}
	LaunchedEffect(Unit) {
		Notifier.start(context)
		BackgroundLocation.start(context)
		if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
			notifyPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
		}
	}
	// a tapped notification: the post on the Diário, or the map's check-in
	LaunchedEffect(Notifier.openRoute) {
		Notifier.openRoute?.let { r -> tab = Tab.Diario; stacks.getValue(Tab.Diario).add(r); Notifier.openRoute = null }
	}
	LaunchedEffect(Notifier.openCheckin) { if (Notifier.openCheckin > 0) { tab = Tab.Mapa; stacks.getValue(Tab.Mapa).clear() } }
	// refresh the feed as uploads reach the server
	val app = LocalApp.current
	val arrivals by Uploads.arrivals.collectAsState()
	LaunchedEffect(arrivals) { if (arrivals > 0) app.feedChanged() }
	// the dock steps aside while the keyboard is up, so text fields stay visible
	val keyboardUp = WindowInsets.isImeVisible

	Box(Modifier.fillMaxSize()) {
		Column(Modifier.fillMaxSize()) {
			Box(Modifier.statusBarsPadding()) { TopBar(tab == Tab.Enviar) { stacks.getValue(Tab.Enviar).clear(); tab = Tab.Enviar } }
			Box(Modifier.weight(1f).fillMaxWidth()) {
				// the tab's main screen stays alive under its pages, so it keeps its scroll position
				when (tab) {
					Tab.Diario -> FeedScreen(DockSpace, open)
					Tab.Roteiro -> RoteiroScreen(DockSpace)
					Tab.Mais -> MoreScreen(DockSpace)
					Tab.Galeria -> GaleriaScreen(DockSpace, open, covered = stack.isNotEmpty())
					Tab.Enviar -> EnviarScreen(DockSpace, open)
					Tab.Mapa -> MapaScreen(DockSpace, open, Notifier.openCheckin)
				}
				AnimatedContent(
					stack.lastOrNull(),
					transitionSpec = { (slideInHorizontally { it } togetherWith slideOutHorizontally { it }) },
					label = "page",
				) { route ->
					if (route != null) Box(Modifier.fillMaxSize().imePadding()) {
						DottedBackground()
						when (route) {
							is Route.Media -> MediaDetailScreen(route.id, DockSpace, back)
							is Route.Checkin -> CheckinDetailScreen(route.id, DockSpace, back)
						}
					}
				}
			}
		}
		AnimatedVisibility(
			!keyboardUp,
			Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 8.dp),
			enter = slideInVertically { it } + fadeIn(),
			exit = slideOutVertically { it } + fadeOut(),
		) { Dock(tab, { if (it == tab) stack.clear() else tab = it }) }
	}
}

/** Placeholder for screens still being built: explains it and links to the same page on the website. */
@Composable
private fun ComingSoon(tab: Tab, webPath: String, open: (String) -> Unit) {
	Box(Modifier.fillMaxSize().padding(20.dp).padding(DockSpace), contentAlignment = Alignment.Center) {
		Column(Modifier.popIn().card(22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
			TitleRow(tab.icon, tab.label)
			Text("Esta tela ainda está sendo feita no app. Enquanto isso, ela funciona no site.", style = body(17), color = Palette.ink, textAlign = TextAlign.Center)
			ChunkyButton("Abrir no site", { open(webPath) }, variant = ButtonVariant.Sea, icon = IconName.Expand)
		}
	}
}
