package com.nelsul.curitibatrip.feature.roteiro

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.LocalApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.feature.feed.EmptyState
import com.nelsul.curitibatrip.ui.components.BackButton
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.card
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display

/** A place's own page (web /roteiro/lugar/:id): photos, how to get there, hours, price, about, its days and their forecast. */
@Composable
fun PlaceDetailScreen(id: String, contentPadding: PaddingValues, back: () -> Unit) {
	val app = LocalApp.current
	val context = LocalContext.current
	var data by remember { mutableStateOf<RoteiroData?>(null) }
	var error by remember { mutableStateOf<String?>(null) }
	var full by remember { mutableStateOf<String?>(null) }
	LaunchedEffect(id) {
		try { data = Api.get("/api/roteiro") } catch (e: Exception) { app.handle(e); error = e.message }
		Weather.load()
	}
	val openUrl: (String) -> Unit = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(it))) }
	val place = data?.places?.firstOrNull { it.id == id }

	Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
		Column(Modifier.widthIn(max = 640.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
			BackButton(back)
			when {
				place != null -> {
					val pager = rememberPagerState { place.photos.size }
					Box(Modifier.fillMaxWidth().aspectRatio(4f / 3f).clip(RoundedCornerShape(22.dp)).background(Palette.surface2).border(2.5.dp, Palette.line, RoundedCornerShape(22.dp))) {
						if (place.photos.isEmpty()) Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
							Icon(IconName.Camera, Palette.muted, size = 34.dp)
							Text("Sem fotos ainda", style = body(15, FontWeight.ExtraBold), color = Palette.muted)
						} else HorizontalPager(pager, Modifier.fillMaxSize()) { i ->
							AsyncImage(place.photos[i].url, if (i == 0) place.name else null, contentScale = ContentScale.Crop,
								modifier = Modifier.fillMaxSize().pressable({ full = place.photos[i].url }))
						}
						Text(place.categoryInfo.label, style = body(12, FontWeight.ExtraBold), color = Color.White,
							modifier = Modifier.padding(10.dp).background(place.categoryInfo.color, CircleShape).padding(horizontal = 10.dp, vertical = 2.dp))
						if (place.photos.size > 1) Text("${pager.currentPage + 1}/${place.photos.size}", style = body(13, FontWeight.ExtraBold), color = Color.White,
							modifier = Modifier.align(Alignment.TopEnd).padding(10.dp).background(Color.Black.copy(alpha = 0.55f), CircleShape).padding(horizontal = 9.dp, vertical = 1.dp))
					}
					Text(place.name, style = display(30), color = Palette.ink)
					if (place.address.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
						Icon(IconName.Pin, Palette.muted, Modifier.padding(top = 2.dp), size = 16.dp)
						Text(place.address, style = body(15), color = Palette.muted)
					}
					Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
						ChunkyButton("Pedir Uber", { openUrl(place.uberUrl) }, variant = ButtonVariant.Uber, small = true, icon = IconName.Car)
						ChunkyButton("Google Maps", { openUrl(place.mapsUrl) }, variant = ButtonVariant.Secondary, small = true, icon = IconName.Map)
						if (place.link.isNotEmpty()) ChunkyButton("Site", { openUrl(place.link) }, variant = ButtonVariant.Secondary, small = true, icon = IconName.External)
					}
					Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
						if (place.hours.isNotEmpty()) Fact(IconName.Clock, "Horário", place.hours)
						if (place.price.isNotEmpty() || place.priceLevel != null) Fact(IconName.Wallet, "Preço", "${Roteiro.priceSigns(place.priceLevel)} ${place.price}".trim())
						if (place.hours.isEmpty() && place.price.isEmpty() && place.priceLevel == null) Text("Sem horário ou preço anotados.", style = body(15), color = Palette.muted)
					}
					if (place.description.isNotEmpty()) {
						Text("Sobre", style = display(21), color = Palette.ink)
						Text(place.description, style = body(16), color = Palette.ink)
					}
					Text("No roteiro", style = display(21), color = Palette.ink)
					val stops = data!!.days.flatMap { d -> d.stops.filter { it.placeId == place.id }.map { d to it } }
					if (stops.isEmpty()) Text("Ainda não está em nenhum dia.", style = body(15), color = Palette.muted)
					stops.forEach { (d, s) ->
						Column(Modifier.fillMaxWidth().card(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
							Row(verticalAlignment = Alignment.CenterVertically) {
								Text(TripTime.longDay(d.date), style = display(17), color = Palette.ink, modifier = Modifier.weight(1f))
								if (s.visitedAt != null) Row(Modifier.background(Palette.leaf, CircleShape).padding(horizontal = 10.dp, vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
									Icon(IconName.Check, Palette.onLeaf, size = 13.dp)
									Text(" Fomos!", style = body(12, FontWeight.ExtraBold), color = Palette.onLeaf)
								}
							}
							Text(listOf(d.title, s.time, RoteiroTransport.of(s.transport).label).filter { it.isNotEmpty() }.joinToString(" · "), style = body(14), color = Palette.muted)
							if (s.note.isNotEmpty()) Text(s.note, style = body(14), color = Palette.ink)
							Weather.days[d.date]?.let { WeatherCard(it) }
						}
					}
				}
				error != null -> EmptyState(error!!)
				data != null -> EmptyState("Lugar não encontrado.")
				else -> CircularProgressIndicator(color = Palette.sea, modifier = Modifier.align(Alignment.CenterHorizontally))
			}
		}
	}
	full?.let { url ->
		Dialog({ full = null }, DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
			Box(Modifier.fillMaxSize().background(Color.Black).pressable({ full = null }).semantics { contentDescription = "Fechar foto" }) {
				AsyncImage(url, null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize().systemBarsPadding())
			}
		}
	}
}

@Composable
private fun Fact(icon: IconName, title: String, value: String) {
	Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
		Box(Modifier.size(38.dp).background(Palette.surface2, RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) { Icon(icon, Palette.sea, size = 20.dp) }
		Column {
			Text(title, style = body(15, FontWeight.ExtraBold), color = Palette.ink)
			Text(value, style = body(15), color = Palette.ink)
		}
	}
}
