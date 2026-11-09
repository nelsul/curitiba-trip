package com.nelsul.curitibatrip

import android.content.Intent
import android.os.Bundle
import com.nelsul.curitibatrip.background.Notifier
import com.nelsul.curitibatrip.data.Route
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.nelsul.curitibatrip.data.TokenStore
import com.nelsul.curitibatrip.feature.login.LoginScreen
import com.nelsul.curitibatrip.feature.shell.Shell
import com.nelsul.curitibatrip.ui.components.DottedBackground
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.TitleRow
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body

class MainActivity : ComponentActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		// Emulator testing only: `adb shell am start -n …/.MainActivity -e debugToken <token>` signs in without the email step.
		if (BuildConfig.DEBUG) intent.getStringExtra("debugToken")?.takeIf { it.isNotBlank() }?.let { TokenStore.save(it) }
		enableEdgeToEdge(SystemBarStyle.dark(Palette.bg.toArgb()), SystemBarStyle.dark(Palette.bg.toArgb()))
		super.onCreate(savedInstanceState)
		handleNotification(intent)
		val app = (application as TripApp).state
		setContent {
			CompositionLocalProvider(LocalApp provides app) {
				LaunchedEffect(Unit) { app.restore() }
				Box(Modifier.fillMaxSize()) {
					DottedBackground()
					// keyed by the kind of phase, so refreshing who's signed in (new photo) doesn't rebuild the screens
					Crossfade(app.phase::class, label = "phase") { _ ->
						when (val phase = app.phase) {
							AppState.Phase.Loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Palette.sea) }
							AppState.Phase.SignedOut -> LoginScreen()
							is AppState.Phase.SignedIn -> {
								// safety net: names and photos need the people list (e.g. it failed while offline at launch)
								LaunchedEffect(Unit) { if (app.people.isEmpty()) app.loadPeople() }
								Shell()
							}
							is AppState.Phase.Outdated -> Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
								androidx.compose.foundation.layout.Column(Modifier.card(22.dp), horizontalAlignment = Alignment.CenterHorizontally) {
									TitleRow(IconName.Plane, "Nova versão")
									Text(
										"Este app precisa ser atualizado (versão ${phase.minVersion} ou mais nova). Fale com o Nelson para receber o novo arquivo.",
										style = body(17), color = Palette.ink, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 14.dp),
									)
								}
							}
						}
					}
				}
			}
		}
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		handleNotification(intent)
	}

	/** A tapped notification: open the post, or the map's check-in. */
	private fun handleNotification(intent: Intent?) {
		intent ?: return
		intent.getStringExtra("media")?.let { Notifier.openRoute = Route.Media(it) }
		intent.getStringExtra("checkin")?.let { Notifier.openRoute = Route.Checkin(it) }
		if (intent.getStringExtra("action") == "checkin") Notifier.openCheckin++
	}
}
