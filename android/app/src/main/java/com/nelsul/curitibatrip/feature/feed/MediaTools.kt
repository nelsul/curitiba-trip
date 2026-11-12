package com.nelsul.curitibatrip.feature.feed

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import android.widget.Toast
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.FeedMedia
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import okhttp3.Request

/**
 * Instagram-style zoom: pinch a photo with two fingers and it grows under the fingers, springing back when
 * they lift. One finger is left alone (the carousel swipe, taps and double taps keep working).
 */
fun Modifier.pinchToZoom(): Modifier = composed {
	val scope = rememberCoroutineScope()
	val scale = remember { Animatable(1f) }
	var offset by remember { mutableStateOf(Offset.Zero) }
	this
		.zIndex(if (scale.value > 1f) 1f else 0f)
		.graphicsLayer { scaleX = scale.value; scaleY = scale.value; translationX = offset.x; translationY = offset.y }
		.pointerInput(Unit) {
			awaitEachGesture {
				awaitFirstDown(requireUnconsumed = false)
				var zoomed = false
				do {
					val event = awaitPointerEvent()
					if (event.changes.count { it.pressed } >= 2) {
						zoomed = true
						val zoom = event.calculateZoom()
						val centroid = event.calculateCentroid(useCurrent = true)
						val center = Offset(size.width / 2f, size.height / 2f)
						val s = (scale.value * zoom).coerceIn(1f, 5f)
						val k = s / scale.value
						// keep the point between the fingers under the fingers
						offset = offset * k + (centroid - center) * (1 - k) + event.calculatePan()
						scope.launch { scale.snapTo(s) }
						event.changes.forEach { it.consume() }
					}
				} while (event.changes.any { it.pressed })
				if (zoomed) scope.launch {
					val from = offset
					launch { scale.animateTo(1f, spring(dampingRatio = 0.8f, stiffness = 500f)) }
					val back = Animatable(1f)
					back.animateTo(0f, spring(dampingRatio = 0.8f, stiffness = 500f)) { offset = from * value }
					offset = Offset.Zero
				}
			}
		}
}

@Serializable
private data class OriginalLink(val url: String, val name: String)

/** Downloads the original file (full quality, as uploaded) into the gallery (Pictures/Movies › Curitiba). */
suspend fun saveOriginal(context: Context, media: FeedMedia) = withContext(Dispatchers.IO) {
	if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) error("Salvar o original precisa do Android 10 ou mais novo.")
	// the signed link, then the file straight from storage
	val link = Api.get<OriginalLink>("/api/media/${media.id}/original", mapOf("link" to "1"))
	val ext = link.name.substringAfterLast('.', "").lowercase()
	val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: if (media.isVideo) "video/mp4" else "image/jpeg"
	val resolver = context.contentResolver
	val collection = if (media.isVideo) MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
		else MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
	val values = ContentValues().apply {
		put(MediaStore.MediaColumns.DISPLAY_NAME, link.name)
		put(MediaStore.MediaColumns.MIME_TYPE, mime)
		put(MediaStore.MediaColumns.RELATIVE_PATH, (if (media.isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES) + "/Curitiba")
		put(MediaStore.MediaColumns.IS_PENDING, 1)
	}
	val uri = resolver.insert(collection, values) ?: error("Não foi possível salvar na galeria.")
	try {
		Api.client.newCall(Request.Builder().url(link.url).build()).execute().use { r ->
			if (!r.isSuccessful) error("Não foi possível baixar o original.")
			resolver.openOutputStream(uri)!!.use { out -> r.body.byteStream().copyTo(out) }
		}
		resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
	} catch (e: Exception) {
		resolver.delete(uri, null, null)
		throw e
	}
}

/** "Salvar original": a download icon that turns into a spinner, then a check when it's in the gallery. */
@Composable
fun SaveOriginalButton(media: FeedMedia, tint: Color = Palette.ink, size: Dp = 24.dp) {
	val context = LocalContext.current
	val scope = rememberCoroutineScope()
	var state by remember(media.id) { mutableIntStateOf(0) } // 0 idle · 1 saving · 2 saved
	Box(
		Modifier.size(44.dp).pressable({
			if (state != 0) return@pressable
			state = 1
			scope.launch {
				try {
					saveOriginal(context, media)
					state = 2
					Toast.makeText(context, "Salvo na galeria (pasta Curitiba)", Toast.LENGTH_SHORT).show()
					delay(2500)
				} catch (e: Exception) {
					Toast.makeText(context, e.message ?: "Não foi possível salvar.", Toast.LENGTH_LONG).show()
				}
				state = 0
			}
		}).semantics { contentDescription = if (state == 2) "Salvo na galeria" else "Salvar original na galeria" },
		contentAlignment = Alignment.Center,
	) {
		when (state) {
			1 -> CircularProgressIndicator(color = tint, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
			2 -> Icon(IconName.Check, Palette.leaf, size = size)
			else -> Icon(IconName.Download, tint, size = size)
		}
	}
}
