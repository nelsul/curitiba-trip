package com.nelsul.curitibatrip.feature.feed

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.data.FeedMedia
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body

/** One row of the photo grid (3 squares, like the phone's gallery); in selecting mode taps pick items in order. */
@Composable
fun MediaGridRow(row: List<FeedMedia>, selecting: Boolean, picked: List<String>, onTap: (FeedMedia) -> Unit) {
	Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
		row.forEach { m ->
			val n = picked.indexOf(m.id)
			val shrink by animateFloatAsState(if (n >= 0) 0.88f else 1f, label = "pick")
			Box(
				Modifier.weight(1f).aspectRatio(1f).background(Palette.surface2).pressable({ onTap(m) })
					.semantics { contentDescription = if (m.isVideo) "Vídeo" else m.caption.ifEmpty { "Foto" }; if (selecting) selected = n >= 0 },
			) {
				AsyncImage(m.thumb ?: m.image, null, contentScale = ContentScale.Crop,
					modifier = Modifier.fillMaxSize().scale(shrink).clip(RoundedCornerShape(if (n >= 0) 8.dp else 0.dp)))
				if (m.isVideo) Row(
					Modifier.align(Alignment.BottomEnd).padding(4.dp).background(Color.Black.copy(alpha = 0.6f), CircleShape).padding(horizontal = 6.dp, vertical = 1.dp),
					verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp),
				) {
					Icon(IconName.Play, Color.White, size = 11.dp)
					m.durationS?.let { d -> Text("%d:%02d".format(d.toInt() / 60, d.toInt() % 60), style = body(11, FontWeight.ExtraBold), color = Color.White) }
				}
				if (selecting) Box(
					Modifier.align(Alignment.TopEnd).padding(6.dp).sizeIn(26.dp, 26.dp)
						.background(if (n >= 0) Palette.sea else Color.Black.copy(alpha = 0.25f), CircleShape).border(2.5.dp, Color.White, CircleShape),
					contentAlignment = Alignment.Center,
				) { if (n >= 0) Text("${n + 1}", style = body(13, FontWeight.ExtraBold), color = Palette.onSea) }
			}
		}
		repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
	}
}

/** Countdown to the wedding at the top of the Diário; afterwards, the way into the Retrospectiva. */
@Composable
fun CountdownCard(onClick: () -> Unit, modifier: Modifier = Modifier, big: Boolean = false) {
	var now by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(java.time.Instant.now()) }
	androidx.compose.runtime.LaunchedEffect(Unit) { while (true) { kotlinx.coroutines.delay(1000); now = java.time.Instant.now() } }
	val left = maxOf(0L, java.time.Duration.between(now, com.nelsul.curitibatrip.data.Wedding.at).seconds)
	val running = left > 0
	val accent = if (running) Palette.berry else Palette.sun
	Row(
		modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp))
			.background(androidx.compose.ui.graphics.Brush.linearGradient(listOf(accent.copy(alpha = 0.3f), Palette.surface)))
			.border(2.5.dp, Palette.berry.copy(alpha = 0.6f), RoundedCornerShape(22.dp))
			.pressable(onClick).padding(horizontal = 18.dp, vertical = 16.dp)
			.semantics { contentDescription = if (running) "Faltam ${left / 86400} dias e ${left / 3600 % 24} horas para o casamento" else "Retrospectiva da viagem" },
		// counting: the ring and the numbers centered in the card
		verticalAlignment = Alignment.CenterVertically,
		horizontalArrangement = if (running) Arrangement.spacedBy(18.dp, Alignment.CenterHorizontally) else Arrangement.spacedBy(12.dp),
	) {
		Box(Modifier.size(if (big) 72.dp else 52.dp).background(accent, RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
			Icon(if (running) IconName.Ring else IconName.Sparkle, if (running) Color.White else Palette.onSun, size = if (big) 40.dp else 28.dp)
		}
		if (running) androidx.compose.foundation.layout.Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
			Text("Contagem para o casamento", style = body(13, FontWeight.ExtraBold), color = Palette.berry)
			Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
				listOf(left / 86400 to "dias", left / 3600 % 24 to "horas", left / 60 % 60 to "min", left % 60 to "seg").forEach { (n, l) ->
					androidx.compose.foundation.layout.Column(horizontalAlignment = Alignment.CenterHorizontally) {
						Text("%02d".format(n), style = com.nelsul.curitibatrip.ui.theme.display(if (big) 40 else 29), color = Palette.ink)
						Text(l, style = body(11, FontWeight.ExtraBold), color = Palette.muted, modifier = Modifier.padding(top = 2.dp))
					}
				}
			}
		} else androidx.compose.foundation.layout.Column {
			Text("Retrospectiva da viagem", style = com.nelsul.curitibatrip.ui.theme.display(19), color = Palette.ink)
			Text("Os melhores momentos, escolhidos a dedo. Toque para ver.", style = body(14), color = Palette.ink)
		}
	}
}
