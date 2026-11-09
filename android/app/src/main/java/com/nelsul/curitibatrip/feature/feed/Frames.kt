package com.nelsul.curitibatrip.feature.feed

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.FileProvider
import androidx.core.content.res.ResourcesCompat
import coil3.imageLoader
import coil3.request.ImageRequest
import coil3.request.allowHardware
import coil3.toBitmap
import com.nelsul.curitibatrip.R
import com.nelsul.curitibatrip.data.FeedMedia
import com.nelsul.curitibatrip.ui.components.ButtonVariant
import com.nelsul.curitibatrip.ui.components.Chip
import com.nelsul.curitibatrip.ui.components.ChunkyButton
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Share frames: up to 9 photos laid out on one image with a frame, for Instagram and WhatsApp.
 * Same layout as the web (web/src/lib/frames.ts) and iOS (Frames.swift): keep the numbers in sync.
 */
object Frames {
	enum class Style(val label: String, val bg: Int, val card: Int, val title: Int, val sub: Int, val line: Int?, val radius: Float, val text: Pair<String, String>) {
		Polaroid("Polaroid", 0xffffffff.toInt(), 0xffeeeeee.toInt(), 0xff1d2a45.toInt(), 0xff3a4d78.toInt(), null, 6f, "Curitiba" to "11 a 18 de novembro de 2026"),
		Passaporte("Passaporte", 0xff18737a.toInt(), 0xff0f5a60.toInt(), 0xfffff6dc.toInt(), 0xfff6d36b.toInt(), 0xfffff6dc.toInt(), 18f, "Viagem a Curitiba" to "11–18 · novembro · 2026"),
		Noite("Noite", 0xff1d2a45.toInt(), 0xff27375a.toInt(), 0xfff6d36b.toInt(), 0xfff4eed6.toInt(), null, 22f, "Curitiba" to "11 a 18 de novembro de 2026"),
		Casamento("Casamento", 0xfffff6dc.toInt(), 0xfff2e6c4.toInt(), 0xfff08bb0.toInt(), 0xff1d2a45.toInt(), 0xfff08bb0.toInt(), 18f, "Casamento" to "14 de novembro de 2026"),
	}

	enum class Format(val label: String, val w: Int, val h: Int) { Post("Post (4:5)", 1080, 1350), Story("Story (9:16)", 1080, 1920) }

	const val MAX = 9
	private const val PAD = 56f
	private const val FOOTER = 200f
	private const val GAP = 14f
	private val rows = mapOf(1 to listOf(1), 2 to listOf(1, 1), 3 to listOf(1, 2), 4 to listOf(2, 2), 5 to listOf(2, 3), 6 to listOf(2, 2, 2), 7 to listOf(2, 2, 3), 8 to listOf(3, 2, 3), 9 to listOf(3, 3, 3))

	fun cells(n: Int, f: Format): List<RectF> {
		val r = rows.getValue(n.coerceIn(1, MAX))
		val aw = f.w - 2 * PAD
		val ah = f.h - 2 * PAD - FOOTER
		val rh = (ah - GAP * (r.size - 1)) / r.size
		return r.flatMapIndexed { i, count ->
			val cw = (aw - GAP * (count - 1)) / count
			(0 until count).map { c -> RectF(PAD + c * (cw + GAP), PAD + i * (rh + GAP), PAD + c * (cw + GAP) + cw, PAD + i * (rh + GAP) + rh) }
		}
	}

	fun render(context: Context, photos: List<Bitmap>, style: Style, format: Format): Bitmap {
		val out = Bitmap.createBitmap(format.w, format.h, Bitmap.Config.ARGB_8888)
		val g = Canvas(out)
		g.drawColor(style.bg)
		style.line?.let { line ->
			g.drawRoundRect(RectF(22f, 22f, format.w - 22f, format.h - 22f), 30f, 30f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = line; this.style = Paint.Style.STROKE; strokeWidth = 4f })
		}
		val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = style.card }
		val img = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
		photos.zip(cells(photos.size, format)).forEach { (b, c) ->
			g.save()
			val clip = Path().apply { addRoundRect(c, style.radius, style.radius, Path.Direction.CW) }
			g.drawPath(clip, fill)
			g.clipPath(clip)
			// cover: fill the cell, cropping the middle
			val k = maxOf(c.width() / b.width, c.height() / b.height)
			val w = b.width * k
			val h = b.height * k
			g.drawBitmap(b, null, RectF(c.centerX() - w / 2, c.centerY() - h / 2, c.centerX() + w / 2, c.centerY() + h / 2), img)
			g.restore()
		}
		val title = Paint(Paint.ANTI_ALIAS_FLAG).apply {
			color = style.title; textSize = 76f; textAlign = Paint.Align.CENTER
			typeface = ResourcesCompat.getFont(context, R.font.fredoka_semibold)
		}
		val sub = Paint(Paint.ANTI_ALIAS_FLAG).apply {
			color = style.sub; textSize = 34f; textAlign = Paint.Align.CENTER
			typeface = ResourcesCompat.getFont(context, R.font.nunito_extrabold)
		}
		g.drawText(style.text.first, format.w / 2f, format.h - PAD - 92f, title)
		g.drawText(style.text.second, format.w / 2f, format.h - PAD - 34f, sub)
		return out
	}

	/** Saves the image in the cache and opens Android's share sheet (Instagram, WhatsApp, Fotos…). */
	fun share(context: Context, bitmap: Bitmap) {
		val dir = File(context.cacheDir, "frames").apply { mkdirs() }
		dir.listFiles()?.forEach { it.delete() }
		val file = File(dir, "curitiba-${System.currentTimeMillis()}.jpg")
		file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 92, it) }
		val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
		val send = Intent(Intent.ACTION_SEND).apply {
			type = "image/jpeg"
			putExtra(Intent.EXTRA_STREAM, uri)
			// lets the share sheet show the picture too
			clipData = android.content.ClipData.newRawUri("", uri)
			addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
		}
		context.startActivity(Intent.createChooser(send, "Compartilhar").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
	}
}

/** Picks a frame style and format for the chosen photos, then shares the image. */
@Composable
fun FrameMakerDialog(items: List<FeedMedia>, onClose: () -> Unit) {
	val context = LocalContext.current
	var photos by remember { mutableStateOf<List<Bitmap>?>(null) }
	var error by remember { mutableStateOf<String?>(null) }
	var style by remember { mutableStateOf(Frames.Style.Polaroid) }
	var format by remember { mutableStateOf(Frames.Format.Post) }
	LaunchedEffect(items) {
		photos = withContext(Dispatchers.IO) {
			items.mapNotNull { m ->
				val req = ImageRequest.Builder(context).data(m.image).allowHardware(false).build()
				context.imageLoader.execute(req).image?.toBitmap()
			}
		}
		if (photos.isNullOrEmpty()) error = "Não foi possível carregar as fotos. Confira a internet."
	}
	val image = remember(photos, style, format) { photos?.takeIf { it.isNotEmpty() }?.let { Frames.render(context, it, style, format) } }

	Dialog(onClose, DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
		Column(Modifier.fillMaxSize().background(Palette.bg).systemBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
			Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
				Text("Moldura", style = display(22), color = Palette.ink, modifier = Modifier.weight(1f))
				Box(Modifier.size(44.dp).background(Palette.surface, CircleShape).pressable(onClose).semantics { contentDescription = "Fechar" }, contentAlignment = Alignment.Center) {
					Icon(IconName.Close, Palette.ink, size = 20.dp)
				}
			}
			Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
				when {
					image != null -> Image(image.asImageBitmap(), "Prévia da imagem com ${items.size} ${if (items.size == 1) "foto" else "fotos"}",
						Modifier.clip(RoundedCornerShape(12.dp)), contentScale = ContentScale.Fit)
					error != null -> Text(error!!, style = body(15, FontWeight.Bold), color = Palette.danger, textAlign = TextAlign.Center)
					else -> CircularProgressIndicator(color = Palette.sea)
				}
			}
			Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
				Frames.Style.entries.forEach { s ->
					Chip(style == s, { style = s }) {
						Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
							Box(Modifier.size(14.dp).background(Color(s.bg), RoundedCornerShape(4.dp)).border(2.dp, Color(s.title), RoundedCornerShape(4.dp)))
							Text(s.label, style = body(15, FontWeight.ExtraBold))
						}
					}
				}
			}
			Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
				Frames.Format.entries.forEach { f -> Chip(format == f, { format = f }) { Text(f.label, style = body(15, FontWeight.ExtraBold)) } }
			}
			ChunkyButton("Compartilhar", { image?.let { Frames.share(context, it) } }, variant = ButtonVariant.Sun, fullWidth = true, enabled = image != null, icon = IconName.Share)
			Text("Abre o Instagram, o WhatsApp e os outros apps.", style = body(13), color = Palette.muted)
		}
	}
}
