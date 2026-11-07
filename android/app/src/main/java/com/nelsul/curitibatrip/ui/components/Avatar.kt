package com.nelsul.curitibatrip.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.display

/** Profile photo in a circle with a ring in the person's color, or their initials on that color. */
@Composable
fun Avatar(name: String, color: Color, photo: String?, size: Dp = 32.dp, modifier: Modifier = Modifier) {
	val ring = maxOf(2f, size.value * 0.06f).dp
	if (photo != null) {
		AsyncImage(
			model = photo, contentDescription = null, contentScale = ContentScale.Crop,
			modifier = modifier.size(size).clip(CircleShape).background(Palette.track).border(ring, color, CircleShape),
		)
	} else {
		Box(modifier.size(size).background(color, CircleShape).border(ring, Color.White, CircleShape), contentAlignment = Alignment.Center) {
			Text(initials(name), style = display((size.value * 0.38f).toInt()), color = Color.White)
		}
	}
}

fun initials(name: String) = name.split(" ").filter { it.isNotBlank() }.take(2).joinToString("") { it.take(1) }.uppercase()

/** "#2F5A40" → Color (people's colors come from the API). */
fun colorOf(hex: String?): Color = runCatching { Color(0xFF000000 or hex!!.removePrefix("#").toLong(16)) }.getOrDefault(Color(0xFF2F5A40))
