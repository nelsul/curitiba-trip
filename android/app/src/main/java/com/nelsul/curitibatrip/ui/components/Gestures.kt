package com.nelsul.curitibatrip.ui.components

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput

/** A plain tap handler that doesn't consume drags or pinches (zoomable images, backdrops). */
fun Modifier.pointerInputTap(onTap: () -> Unit): Modifier = pointerInput(onTap) { detectTapGestures(onTap = { onTap() }) }
