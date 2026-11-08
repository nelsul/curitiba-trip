package com.nelsul.curitibatrip.feature.mapa

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import androidx.compose.ui.graphics.toArgb
import androidx.core.content.res.ResourcesCompat
import com.nelsul.curitibatrip.R
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.Me
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.theme.Palette
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import okhttp3.Request
import org.maplibre.android.geometry.LatLng
import java.io.ByteArrayOutputStream
import java.time.Instant
import java.time.format.DateTimeFormatter

/**
 * The picture of the map at a check-in (web map-snapshot.ts, iOS CheckinSnapshot): island map, the person's pin
 * with their face, a "Nome · 19:56" label. MapLibre adds the map attribution. Uploaded for the diary.
 */
object CheckinSnapshot {
	private const val W = 540
	private const val H = 360

	private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

	/**
	 * Makes the picture from the map on screen (centered on the check-in) and uploads it in the background, on its
	 * own scope so closing the check-in dialog doesn't cancel it. Never fails loudly: the diary shows a plain
	 * banner when there's no picture.
	 */
	fun attachInBackground(context: Context, controller: MapController, checkinId: String, lat: Double, lng: Double, me: Me, done: () -> Unit) {
		val app = context.applicationContext
		scope.launch {
			try {
				val face = me.photo?.let { url -> withContext(Dispatchers.IO) { runCatching { Api.client.newCall(Request.Builder().url(url).build()).execute().use { BitmapFactory.decodeStream(it.body.byteStream()) } }.getOrNull() } }
				val screen = controller.captureAt(LatLng(lat, lng)) ?: throw IllegalStateException("mapa indisponível")
				val jpeg = withContext(Dispatchers.Default) { draw(app, crop(screen), me, face) }
				Api.put<JsonObject>("/api/checkins/$checkinId/snapshot", jpeg, "image/jpeg")
				done()
			} catch (e: Exception) {
				android.util.Log.w("Snapshot", "check-in picture failed: ${e.message}")
			}
		}
	}

	/** The 3:2 middle of the screen map (the check-in point is its center), as a 1080×720 picture. */
	private fun crop(screen: Bitmap): Bitmap {
		var w = screen.width
		var h = w * 2 / 3
		if (h > screen.height) { h = screen.height; w = h * 3 / 2 }
		val part = Bitmap.createBitmap(screen, (screen.width - w) / 2, (screen.height - h) / 2, w, h)
		return Bitmap.createScaledBitmap(part, W * 2, H * 2, true).copy(Bitmap.Config.ARGB_8888, true)
	}

	private fun draw(context: Context, map: Bitmap, me: Me, face: Bitmap?): ByteArray {
		val s = map.width / W.toFloat()
		val out = map
		val c = Canvas(out)
		c.scale(s, s)
		val color = colorOf(me.color).toArgb()
		val p = Paint(Paint.ANTI_ALIAS_FLAG)
		// soft vignette so the pin pops
		p.shader = RadialGradient(W / 2f, H / 2f, W * 0.7f, intArrayOf(0x001D2A45, 0x590A101E), floatArrayOf(0.2f, 1f), Shader.TileMode.CLAMP)
		c.drawRect(0f, 0f, W.toFloat(), H.toFloat(), p)
		p.shader = null
		// pin: tip exactly on the check-in point (the map center)
		val tx = W / 2f; val ty = H / 2f; val r = 30f; val hy = ty - 58f
		p.color = 0x40000000
		c.drawOval(RectF(tx - 16, ty - 3, tx + 16, ty + 7), p)
		val pin = Path().apply {
			moveTo(tx, ty)
			cubicTo(tx - 14, ty - 18, tx - r, hy + r * 0.6f, tx - r, hy)
			arcTo(RectF(tx - r, hy - r, tx + r, hy + r), 180f, 180f)
			cubicTo(tx + r, hy + r * 0.6f, tx + 14, ty - 18, tx, ty)
			close()
		}
		p.color = color; p.style = Paint.Style.FILL
		c.drawPath(pin, p)
		p.color = android.graphics.Color.WHITE; p.style = Paint.Style.STROKE; p.strokeWidth = 4f
		c.drawPath(pin, p)
		p.style = Paint.Style.FILL
		// face (or initial) inside the pin head
		val fr = r - 6
		if (face != null) {
			c.save()
			c.clipPath(Path().apply { addCircle(tx, hy, fr, Path.Direction.CW) })
			c.drawBitmap(face, null, RectF(tx - fr, hy - fr, tx + fr, hy + fr), Paint(Paint.FILTER_BITMAP_FLAG))
			c.restore()
		} else {
			p.color = android.graphics.Color.WHITE
			c.drawCircle(tx, hy, fr, p)
			p.color = color; p.textSize = 26f; p.textAlign = Paint.Align.CENTER
			p.typeface = ResourcesCompat.getFont(context, R.font.fredoka_semibold)
			c.drawText(me.name.take(1).uppercase(), tx, hy + 9f, p)
		}
		// label: "Nelson · 19:56"
		val time = DateTimeFormatter.ofPattern("HH:mm").withZone(com.nelsul.curitibatrip.data.TripTime.zone).format(Instant.now())
		val label = "${me.name} · $time"
		p.typeface = ResourcesCompat.getFont(context, R.font.fredoka_semibold); p.textSize = 17f; p.textAlign = Paint.Align.LEFT
		val lw = p.measureText(label) + 28f
		val pill = RectF(14f, H - 50f, 14f + lw, H - 14f)
		p.color = Palette.surface.toArgb(); c.drawRoundRect(pill, 18f, 18f, p)
		p.color = Palette.line.toArgb(); p.style = Paint.Style.STROKE; p.strokeWidth = 2.5f; c.drawRoundRect(pill, 18f, 18f, p)
		p.style = Paint.Style.FILL; p.color = Palette.ink.toArgb()
		c.drawText(label, 28f, H - 26f, p)
		// attribution (required by the map data license)
		p.typeface = ResourcesCompat.getFont(context, R.font.nunito_bold); p.textSize = 9f; p.textAlign = Paint.Align.RIGHT
		p.color = Palette.ink.copy(alpha = 0.7f).toArgb()
		c.drawText("© OpenStreetMap · OpenFreeMap", W - 8f, H - 8f, p)
		return ByteArrayOutputStream().also { out.compress(Bitmap.CompressFormat.JPEG, 86, it) }.toByteArray()
	}
}
