package com.nelsul.curitibatrip.feature.feed

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.LinearGradient
import android.graphics.Shader
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
import kotlinx.coroutines.launch
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.ui.components.AppTextField
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Share frames: up to 9 photos laid out on one image with a frame, for Instagram and WhatsApp.
 * Same layout as the web (web/src/lib/frames.ts) and iOS (Frames.swift): keep the numbers in sync.
 */
object Frames {
	/** Decoration on top of the background; the shapes and sizes are described in web/src/lib/frames.ts. */
	enum class Deco { None, Line, Airmail, Film, Ticket, Dots }

	enum class Style(
		val label: String, val bg: Int, val card: Int, val title: Int, val sub: Int, val line: Int?, val deco: Deco, val radius: Float,
		val text: Pair<String, String>, val bg2: Int? = null,
	) {
		Polaroid("Polaroid", 0xffffffff.toInt(), 0xffeeeeee.toInt(), 0xff1d2a45.toInt(), 0xff3a4d78.toInt(), null, Deco.None, 6f, "Curitiba" to "11 a 18 de novembro de 2026"),
		Passaporte("Passaporte", 0xff18737a.toInt(), 0xff0f5a60.toInt(), 0xfffff6dc.toInt(), 0xfff6d36b.toInt(), 0xfffff6dc.toInt(), Deco.Line, 18f, "Viagem a Curitiba" to "11–18 · novembro · 2026"),
		Noite("Noite", 0xff1d2a45.toInt(), 0xff27375a.toInt(), 0xfff6d36b.toInt(), 0xfff4eed6.toInt(), null, Deco.None, 22f, "Curitiba" to "11 a 18 de novembro de 2026"),
		Casamento("Casamento", 0xfffff6dc.toInt(), 0xfff2e6c4.toInt(), 0xfff08bb0.toInt(), 0xff1d2a45.toInt(), 0xfff08bb0.toInt(), Deco.Line, 18f, "Casamento" to "14 de novembro de 2026"),
		Postal("Cartão-postal", 0xfffbf3df.toInt(), 0xffefe3c2.toInt(), 0xff2f5aa8.toInt(), 0xffd9534f.toInt(), 0xffd9534f.toInt(), Deco.Airmail, 6f, "Lembranças de Curitiba" to "11 a 18 de novembro de 2026"),
		Filme("Filme", 0xff141414.toInt(), 0xff262626.toInt(), 0xfff4eed6.toInt(), 0xfff6d36b.toInt(), 0xfff4eed6.toInt(), Deco.Film, 4f, "Curitiba" to "11 a 18 · nov · 2026"),
		Ingresso("Ingresso", 0xfff6d36b.toInt(), 0xffe9c24f.toInt(), 0xff1d2a45.toInt(), 0xff9a4a1e.toInt(), 0xff1d2a45.toInt(), Deco.Ticket, 14f, "Curitiba" to "Embarque 11/11 · Volta 18/11"),
		PorDoSol("Pôr do sol", 0xfff7a35c.toInt(), 0xffc8677a.toInt(), 0xfffff6dc.toInt(), 0xfffff6dc.toInt(), null, Deco.None, 24f, "Curitiba" to "11 a 18 de novembro de 2026", bg2 = 0xff7b3f8f.toInt()),
		Araucaria("Araucária", 0xff2f5a40.toInt(), 0xff244a34.toInt(), 0xfff6d36b.toInt(), 0xffe8f1d8.toInt(), 0xff8fc47a.toInt(), Deco.Dots, 18f, "Curitiba" to "Terra das araucárias · 2026"),
	}

	/** The subtitle when "Local e data" is on: "Jardim Botânico · 14 de novembro". */
	fun caption(place: String, day: String) = listOf(place.trim(), day).filter { it.isNotEmpty() }.joinToString(" · ")

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

	private fun deco(g: Canvas, s: Style, W: Float, H: Float) {
		val line = s.line ?: return
		val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = line }
		when (s.deco) {
			Deco.None -> {}
			Deco.Line -> g.drawRoundRect(RectF(22f, 22f, W - 22f, H - 22f), 30f, 30f, p.apply { style = Paint.Style.STROKE; strokeWidth = 4f })
			Deco.Airmail -> {
				var x = -H
				while (x < W + H) {
					for ((dx, c) in listOf(0f to 0xffd9534f.toInt(), 60f to 0xff2f5aa8.toInt())) {
						p.color = c
						g.drawPath(Path().apply { moveTo(x + dx, 0f); lineTo(x + dx + 40, 0f); lineTo(x + dx + 40 - H, H); lineTo(x + dx - H, H); close() }, p)
					}
					x += 120
				}
				p.color = s.bg
				g.drawRect(24f, 24f, W - 24f, H - 24f, p)
			}
			Deco.Film -> {
				var y = 30f
				while (y + 40 <= H - 20) {
					g.drawRoundRect(RectF(15f, y, 41f, y + 40), 6f, 6f, p)
					g.drawRoundRect(RectF(W - 41f, y, W - 15f, y + 40), 6f, 6f, p)
					y += 70
				}
			}
			Deco.Ticket -> {
				val y = H - PAD - FOOTER + 26
				val dash = Paint(p).apply { style = Paint.Style.STROKE; strokeWidth = 4f; pathEffect = DashPathEffect(floatArrayOf(18f, 14f), 0f) }
				g.drawLine(44f, y, W - 44f, y, dash)
				g.drawCircle(0f, y, 30f, p)
				g.drawCircle(W, y, 30f, p)
			}
			Deco.Dots -> {
				val inset = 30f
				val nx = Math.round((W - 2 * inset) / 34)
				val ny = Math.round((H - 2 * inset) / 34)
				for (i in 0..nx) {
					val x = inset + (W - 2 * inset) * i / nx
					g.drawCircle(x, inset, 6f, p)
					g.drawCircle(x, H - inset, 6f, p)
				}
				for (i in 1 until ny) {
					val y = inset + (H - 2 * inset) * i / ny
					g.drawCircle(inset, y, 6f, p)
					g.drawCircle(W - inset, y, 6f, p)
				}
			}
		}
	}

	/** Centered at the baseline, shrunk to fit the width if it's too long (as on the web). */
	private fun fitText(g: Canvas, text: String, paint: Paint, x: Float, y: Float, maxW: Float) {
		val w = paint.measureText(text)
		if (w > maxW) paint.textSize = kotlin.math.floor(paint.textSize * maxW / w)
		g.drawText(text, x, y, paint)
	}

	/** [caption] replaces the style's subtitle (the "Local e data" option). */
	fun render(context: Context, photos: List<Bitmap>, style: Style, format: Format, caption: String? = null): Bitmap {
		val out = Bitmap.createBitmap(format.w, format.h, Bitmap.Config.ARGB_8888)
		val g = Canvas(out)
		val W = format.w.toFloat()
		val H = format.h.toFloat()
		if (style.bg2 != null) {
			g.drawRect(0f, 0f, W, H, Paint().apply { shader = LinearGradient(0f, 0f, 0f, H, style.bg, style.bg2, Shader.TileMode.CLAMP) })
		} else g.drawColor(style.bg)
		deco(g, style, W, H)
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
		val maxW = W - 2 * PAD - 40
		fitText(g, style.text.first, title, W / 2, H - PAD - 92f, maxW)
		fitText(g, caption?.takeIf { it.isNotEmpty() } ?: style.text.second, sub, W / 2, H - PAD - 34f, maxW)
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

@kotlinx.serialization.Serializable
private data class PlaceHere(val name: String)

/** Picks a frame style and format for the chosen photos, then shares the image. */
@Composable
fun FrameMakerDialog(items: List<FeedMedia>, onClose: () -> Unit) {
	val context = LocalContext.current
	var photos by remember { mutableStateOf<List<Bitmap>?>(null) }
	var error by remember { mutableStateOf<String?>(null) }
	var style by remember { mutableStateOf(Frames.Style.Polaroid) }
	var format by remember { mutableStateOf(Frames.Format.Post) }
	// "Local e data": where you are now (the trip's place or the neighborhood) and today's date
	var withPlace by remember { mutableStateOf(false) }
	var place by remember { mutableStateOf("") }
	var locating by remember { mutableStateOf(false) }
	val today = remember { java.time.format.DateTimeFormatter.ofPattern("d 'de' MMMM", com.nelsul.curitibatrip.data.TripTime.locale).format(java.time.ZonedDateTime.now(com.nelsul.curitibatrip.data.TripTime.zone)) }
	val scope = androidx.compose.runtime.rememberCoroutineScope()
	fun togglePlace() {
		withPlace = !withPlace
		if (!withPlace || place.isNotEmpty()) return
		locating = true
		scope.launch {
			// where you are now (if location is allowed); else where the first photo was taken; else Curitiba
			val here = runCatching { com.nelsul.curitibatrip.data.LocationOnce.current(context) }.getOrNull()?.let { it.latitude to it.longitude }
				?: items.firstOrNull { it.lat != null && it.lng != null }?.let { it.lat!! to it.lng!! }
			val name = here?.let { (lat, lng) ->
				runCatching { Api.get<PlaceHere>("/api/places/here", mapOf("lat" to lat.toString(), "lng" to lng.toString())).name }.getOrNull()
			}
			if (place.isEmpty()) place = name ?: "Curitiba"
			locating = false
		}
	}
	val caption = if (withPlace) Frames.caption(place, today) else null
	LaunchedEffect(items) {
		photos = withContext(Dispatchers.IO) {
			items.mapNotNull { m ->
				val req = ImageRequest.Builder(context).data(m.image).allowHardware(false).build()
				context.imageLoader.execute(req).image?.toBitmap()
			}
		}
		if (photos.isNullOrEmpty()) error = "Não foi possível carregar as fotos. Confira a internet."
	}
	val image = remember(photos, style, format, caption) { photos?.takeIf { it.isNotEmpty() }?.let { Frames.render(context, it, style, format, caption) } }

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
							Box(Modifier.size(14.dp).background(androidx.compose.ui.graphics.Brush.verticalGradient(listOf(Color(s.bg), Color(s.bg2 ?: s.bg))), RoundedCornerShape(4.dp)).border(2.dp, Color(s.title), RoundedCornerShape(4.dp)))
							Text(s.label, style = body(15, FontWeight.ExtraBold))
						}
					}
				}
			}
			Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
				Frames.Format.entries.forEach { f -> Chip(format == f, { format = f }) { Text(f.label, style = body(15, FontWeight.ExtraBold)) } }
			}
			Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
				Chip(withPlace, { togglePlace() }) {
					Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
						Icon(IconName.Pin, if (withPlace) Palette.onSea else Palette.ink, size = 16.dp)
						Text("Local e data", style = body(15, FontWeight.ExtraBold))
					}
				}
				if (withPlace) Text(today, style = body(14, FontWeight.Bold), color = Palette.muted)
			}
			if (withPlace) {
				AppTextField(place, { place = it.take(40) }, if (locating) "Procurando onde você está…" else "Onde vocês estão?", Modifier.fillMaxWidth(), singleLine = true)
			}
			ChunkyButton("Compartilhar", { image?.let { Frames.share(context, it) } }, variant = ButtonVariant.Sun, fullWidth = true, enabled = image != null, icon = IconName.Share)
			Text("Abre o Instagram, o WhatsApp e os outros apps.", style = body(13), color = Palette.muted)
		}
	}
}
