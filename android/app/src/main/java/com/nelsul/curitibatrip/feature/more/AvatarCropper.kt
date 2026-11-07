package com.nelsul.curitibatrip.feature.more

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.DottedBackground
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Loads a picked photo upright and no bigger than 2048 px (big originals waste memory). */
fun loadForCrop(context: Context, uri: Uri): Bitmap? = runCatching {
	if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
		ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri)) { decoder, info, _ ->
			val k = min(1f, 2048f / max(info.size.width, info.size.height))
			decoder.setTargetSize((info.size.width * k).roundToInt(), (info.size.height * k).roundToInt())
			decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
		}
	} else {
		val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
		context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
		var sample = 1
		while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 2048) sample *= 2
		context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample }) }
	}
}.getOrNull()

/** Circle framer (web AvatarCropper): drag to move, pinch or slider to zoom; the image always covers the circle. */
@Composable
fun AvatarCropper(image: Bitmap, onDone: (ByteArray) -> Unit, onCancel: () -> Unit) {
	val stageDp = 300.dp
	val stage = with(LocalDensity.current) { stageDp.toPx() }
	val cover = stage / min(image.width, image.height) // px on screen per image px at scale 1
	var scale by remember { mutableFloatStateOf(1f) }
	var offset by remember { mutableStateOf(Offset.Zero) }
	val bitmap = remember(image) { image.asImageBitmap() }

	fun clamp(o: Offset, s: Float): Offset {
		val maxX = (image.width * cover * s - stage) / 2
		val maxY = (image.height * cover * s - stage) / 2
		return Offset(o.x.coerceIn(-maxX, maxX), o.y.coerceIn(-maxY, maxY))
	}

	/** The square under the circle, at up to 512 px, as JPEG. */
	fun render(): ByteArray {
		val k = cover * scale
		val side = stage / k
		val left = (image.width - side) / 2 - offset.x / k
		val top = (image.height - side) / 2 - offset.y / k
		val out = min(512, side.roundToInt()).coerceAtLeast(64)
		val result = Bitmap.createBitmap(out, out, Bitmap.Config.ARGB_8888)
		android.graphics.Canvas(result).drawBitmap(
			image,
			android.graphics.Rect(left.roundToInt(), top.roundToInt(), (left + side).roundToInt(), (top + side).roundToInt()),
			android.graphics.Rect(0, 0, out, out),
			android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG),
		)
		return ByteArrayOutputStream().also { result.compress(Bitmap.CompressFormat.JPEG, 88, it) }.toByteArray()
	}

	Dialog(onCancel, DialogProperties(usePlatformDefaultWidth = false)) {
		Box(Modifier.fillMaxSize()) {
			DottedBackground()
			Column(Modifier.fillMaxSize().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically)) {
				Text("Ajustar foto", style = display(26), color = Palette.ink)
				Text("Arraste para mover e use o controle (ou dois dedos) para aproximar.", style = body(15), color = Palette.muted, textAlign = TextAlign.Center)
				Canvas(
					Modifier
						.size(stageDp)
						.clip(RoundedCornerShape(18.dp))
						.pointerInput(Unit) {
							detectTransformGestures { _, pan, zoom, _ ->
								scale = (scale * zoom).coerceIn(1f, 6f)
								offset = clamp(offset + pan, scale)
							}
						},
				) {
					val w = image.width * cover * scale
					val h = image.height * cover * scale
					drawImage(
						bitmap,
						dstOffset = IntOffset(((size.width - w) / 2 + offset.x).roundToInt(), ((size.height - h) / 2 + offset.y).roundToInt()),
						dstSize = IntSize(w.roundToInt(), h.roundToInt()),
					)
					// dim everything outside the circle (even-odd: the square minus the circle), then the dashed guide
					val dim = Path().apply {
						fillType = PathFillType.EvenOdd
						addRect(Rect(Offset.Zero, size))
						addOval(Rect(Offset.Zero, size))
					}
					drawPath(dim, Color.Black.copy(alpha = 0.6f))
					val sw = 3.dp.toPx()
					drawCircle(Color.White.copy(alpha = 0.85f), radius = size.minDimension / 2 - sw / 2,
						style = Stroke(sw, pathEffect = PathEffect.dashPathEffect(floatArrayOf(8.dp.toPx(), 6.dp.toPx()))))
				}
				Row(Modifier.width(stageDp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
					Icon(IconName.Camera, Palette.muted, size = 16.dp)
					Slider(scale, { scale = it; offset = clamp(offset, it) }, valueRange = 1f..6f, modifier = Modifier.weight(1f),
						colors = SliderDefaults.colors(thumbColor = Palette.sea, activeTrackColor = Palette.sea, inactiveTrackColor = Palette.track))
					Text("${(scale * 100).roundToInt()}%", style = body(13), color = Palette.muted, modifier = Modifier.width(46.dp))
				}
				Row(Modifier.width(stageDp)) {
					ChunkyButton("Cancelar", onCancel, variant = ButtonVariant.Secondary)
					Spacer(Modifier.weight(1f))
					ChunkyButton("Usar foto", { onDone(render()) }, variant = ButtonVariant.Sun)
				}
			}
		}
	}
}
