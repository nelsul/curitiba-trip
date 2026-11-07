package com.nelsul.curitibatrip.feature.shell

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
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
	// the dock steps aside while the keyboard is up, so text fields stay visible
	val keyboardUp = WindowInsets.isImeVisible

	Box(Modifier.fillMaxSize()) {
		Column(Modifier.fillMaxSize()) {
			Box(Modifier.statusBarsPadding()) { TopBar() }
			Box(Modifier.weight(1f).fillMaxWidth()) {
				when (tab) {
					Tab.Diario -> FeedScreen(DockSpace, openWeb)
					else -> ComingSoon(tab, when (tab) { Tab.Mapa -> "/mapa"; Tab.Enviar -> "/enviar"; Tab.Roteiro -> "/roteiro"; else -> "/mais" }, openWeb)
				}
			}
		}
		AnimatedVisibility(
			!keyboardUp,
			Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 8.dp),
			enter = slideInVertically { it } + fadeIn(),
			exit = slideOutVertically { it } + fadeOut(),
		) { Dock(tab, { tab = it }) }
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
