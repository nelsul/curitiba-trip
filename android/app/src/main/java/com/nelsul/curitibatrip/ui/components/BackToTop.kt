package com.nelsul.curitibatrip.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.display

/** "Topo": a round button that brings a long list back to its start (Diário and Todas as fotos). */
@Composable
fun BackToTopButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
	Row(
		modifier
			.chunky(Palette.sea, Palette.seaDark, 999.dp, 3.dp)
			.pressable(onClick)
			.heightIn(min = 44.dp)
			.padding(start = 10.dp, end = 14.dp)
			.semantics { contentDescription = "Voltar ao topo" },
		verticalAlignment = Alignment.CenterVertically,
		horizontalArrangement = Arrangement.spacedBy(4.dp),
	) {
		Icon(IconName.Up, Palette.onSea, size = 18.dp)
		Text("Topo", style = display(16), color = Palette.onSea)
	}
}
