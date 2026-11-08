package com.nelsul.curitibatrip.feature.mapa

import android.graphics.PointF
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.data.LatestLocation
import com.nelsul.curitibatrip.data.MapItem
import com.nelsul.curitibatrip.data.TripTime
import com.nelsul.curitibatrip.ui.components.Avatar
import com.nelsul.curitibatrip.ui.components.Icon
import com.nelsul.curitibatrip.ui.components.IconName
import com.nelsul.curitibatrip.ui.components.colorOf
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import kotlinx.coroutines.delay
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import java.time.Duration
import java.time.Instant
import kotlin.math.abs
import kotlin.random.Random

/** What the map controller can be asked to do (the screen sets these). */
class MapController {
	internal var map: MapLibreMap? = null
	internal var view: MapView? = null

	/**
	 * Flies to `p`, waits until the map there is fully drawn, and returns a picture of the visible map (the check-in
	 * picture). Uses the on-screen map, which works on every phone (off-screen snapshots
	 * depend on the GPU driver).
	 */
	suspend fun captureAt(p: LatLng): android.graphics.Bitmap? {
		val m = map ?: return null
		val v = view ?: return null
		kotlinx.coroutines.suspendCancellableCoroutine<Unit> { c ->
			m.animateCamera(CameraUpdateFactory.newLatLngZoom(p, 16.0), 1200, object : MapLibreMap.CancelableCallback {
				override fun onCancel() { if (c.isActive) c.resume(Unit) {} }
				override fun onFinish() { if (c.isActive) c.resume(Unit) {} }
			})
		}
		run {
			kotlinx.coroutines.withTimeoutOrNull(10_000) {
				kotlinx.coroutines.suspendCancellableCoroutine<Unit> { c ->
					val l = object : MapView.OnDidFinishRenderingMapListener {
						override fun onDidFinishRenderingMap(fully: Boolean) {
							if (fully) { v.removeOnDidFinishRenderingMapListener(this); if (c.isActive) c.resume(Unit) {} }
						}
					}
					v.addOnDidFinishRenderingMapListener(l)
					m.triggerRepaint()
					c.invokeOnCancellation { v.removeOnDidFinishRenderingMapListener(l) }
				}
			}
			return kotlinx.coroutines.suspendCancellableCoroutine { c -> m.snapshot { b -> if (c.isActive) c.resume(b) {} } }
		}
	}

	fun fit(points: List<LatLng>, padding: IntArray = intArrayOf(160, 260, 160, 520)) {
		val m = map ?: return
		if (points.isEmpty()) return
		if (points.size == 1) return m.animateCamera(CameraUpdateFactory.newLatLngZoom(points[0], 15.0), 800)
		val b = LatLngBounds.Builder().includes(points).build()
		m.animateCamera(CameraUpdateFactory.newLatLngBounds(b, padding[0], padding[1], padding[2], padding[3]), 800, object : MapLibreMap.CancelableCallback {
			override fun onCancel() {}
			override fun onFinish() { if (m.cameraPosition.zoom > 15) m.animateCamera(CameraUpdateFactory.zoomTo(15.0)) }
		})
	}
	fun flyTo(p: LatLng, zoom: Double = 16.0) { map?.animateCamera(CameraUpdateFactory.newLatLngZoom(p, zoom), 1200) }
	val center: LatLng? get() = map?.cameraPosition?.target
	val zoom: Double? get() = map?.cameraPosition?.zoom
}

/**
 * MapLibre with the trip's markers (polaroids, check-in pins, people) drawn as Compose views on top, so they
 * look and animate exactly like the iOS and web markers, and the blue "you are here" dot.
 */
@Composable
fun TripMap(
	styleJson: String,
	controller: MapController,
	modifier: Modifier = Modifier,
	items: List<MapItem> = emptyList(),
	/** Where I am (after "Ir para onde estou"): drawn as the blue dot. */
	me: LatLng? = null,
	people: List<LatestLocation> = emptyList(),
	initial: LatLng = LatLng(-25.4284, -49.2733),
	initialZoom: Double = 12.0,
	onReady: () -> Unit = {},
	onOpenItem: (MapItem) -> Unit = {},
	onCameraIdle: (LatLng) -> Unit = {},
) {
	val context = LocalContext.current
	val lifecycle = LocalLifecycleOwner.current.lifecycle
	var style by remember { mutableStateOf<Style?>(null) }
	var tick by remember { mutableIntStateOf(0) } // bumps as the camera moves, so markers follow
	val mapView = remember {
		MapView(context).apply {
			controller.view = this
			onCreate(null)
			getMapAsync { m ->
				controller.map = m
				m.uiSettings.isLogoEnabled = false
				m.uiSettings.isRotateGesturesEnabled = false
				m.uiSettings.setAttributionMargins(0, 0, 24, 24)
				m.moveCamera(CameraUpdateFactory.newLatLngZoom(initial, initialZoom))
				m.addOnCameraMoveListener { tick++ }
				m.addOnCameraIdleListener { tick++; onCameraIdle(m.cameraPosition.target ?: initial) }
				m.setStyle(Style.Builder().fromJson(styleJson)) { s ->
					style = s
					tick++
					onReady()
				}
			}
		}
	}
	DisposableEffect(lifecycle) {
		val obs = LifecycleEventObserver { _, e ->
			when (e) {
				Lifecycle.Event.ON_START -> mapView.onStart()
				Lifecycle.Event.ON_RESUME -> mapView.onResume()
				Lifecycle.Event.ON_PAUSE -> mapView.onPause()
				Lifecycle.Event.ON_STOP -> mapView.onStop()
				else -> {}
			}
		}
		lifecycle.addObserver(obs)
		if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) mapView.onStart()
		if (lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) mapView.onResume()
		onDispose {
			lifecycle.removeObserver(obs)
			mapView.onPause(); mapView.onStop(); mapView.onDestroy()
			controller.map = null
			controller.view = null
		}
	}
	Box(modifier) {
		AndroidView({ mapView }, Modifier.fillMaxSize())
		val map = controller.map
		if (style != null && map != null) {
			@Suppress("UNUSED_EXPRESSION") tick // re-place markers when the camera moves
			val proj = map.projection
			val density = LocalDensity.current
			fun at(lat: Double, lng: Double): PointF = proj.toScreenLocation(LatLng(lat, lng))
			people.forEach { p ->
				val pt = at(p.lat, p.lng)
				Anchored(pt, 150.dp, 74.dp, bottom = true, density) { PersonMarker(p) }
			}
			items.forEach { it ->
				val lat = it.lat ?: return@forEach
				val lng = it.lng ?: return@forEach
				val pt = at(lat, lng)
				if (it.type == "checkin") Anchored(pt, 56.dp, 64.dp, bottom = true, density) {
					PinMarker(colorFor(it.userId), Modifier.pressable({ onOpenItem(it) }).semantics { contentDescription = "Check-in" })
				} else Anchored(pt, 64.dp, 72.dp, bottom = false, density) {
					PolaroidMarker(it, colorFor(it.userId), Modifier.pressable({ onOpenItem(it) }).semantics { contentDescription = if (it.isVideo) "Vídeo" else "Foto" })
				}
			}
			me?.let { Anchored(at(it.latitude, it.longitude), 48.dp, 48.dp, bottom = false, density) { MeDot() } }
		}
	}
}

/** The pulsing blue "you are here" dot (web .me-dot). */
@Composable
private fun MeDot() {
	val pulse = androidx.compose.animation.core.rememberInfiniteTransition(label = "me")
	val p by pulse.animateFloat(0f, 1f, androidx.compose.animation.core.infiniteRepeatable(androidx.compose.animation.core.tween(2000)), label = "pulse")
	val blue = Color(0xFF3B8CFF)
	androidx.compose.foundation.Canvas(Modifier.size(48.dp).semantics { contentDescription = "Você está aqui" }) {
		drawCircle(blue.copy(alpha = 0.5f * (1f - p)), radius = (9.dp + 16.dp * p).toPx())
		drawCircle(Color.White, radius = 12.dp.toPx())
		drawCircle(blue, radius = 9.dp.toPx())
	}
}

/** People's colors, set by the screen (LocalApp isn't needed here). */
var markerColors: Map<String, Color> = emptyMap()
private fun colorFor(userId: String) = markerColors[userId] ?: Palette.muted

@Composable
private fun Anchored(pt: PointF, w: Dp, h: Dp, bottom: Boolean, density: androidx.compose.ui.unit.Density, content: @Composable () -> Unit) {
	val wp = with(density) { w.toPx() }
	val hp = with(density) { h.toPx() }
	Box(
		Modifier
			.offset { IntOffset((pt.x - wp / 2).toInt(), (if (bottom) pt.y - hp else pt.y - hp / 2).toInt()) }
			.size(w, h),
		contentAlignment = if (bottom) Alignment.BottomCenter else Alignment.Center,
	) { content() }
}

/** Small stable tilt per id, so polaroids look hand-placed but don't jump around (same as web/iOS). */
fun tiltFor(id: String): Float {
	var h = 0
	for (c in id) h = h * 31 + c.code
	return ((abs(h) % 9) - 4) * 1.2f
}

@Composable
private fun PolaroidMarker(item: MapItem, color: Color, modifier: Modifier) {
	val pop = remember { Animatable(0f) }
	LaunchedEffect(item.id) { delay(Random.nextLong(0, 400)); pop.animateTo(1f, spring(dampingRatio = 0.55f, stiffness = 200f)) }
	Box(
		modifier
			.graphicsLayer { scaleX = pop.value; scaleY = pop.value; alpha = pop.value.coerceIn(0f, 1f); translationY = (1 - pop.value) * 20.dp.toPx() }
			.rotate(tiltFor(item.id))
			.shadow(4.dp, RoundedCornerShape(5.dp))
			.background(Palette.polaroid, RoundedCornerShape(5.dp))
			.padding(start = 4.dp, top = 4.dp, end = 4.dp, bottom = 9.dp),
	) {
		Box(Modifier.size(40.dp, 38.dp).clip(RoundedCornerShape(2.dp)).background(Color(0xFFE9E0BF)), contentAlignment = Alignment.Center) {
			AsyncImage(item.thumb, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
			if (item.isVideo) Icon(IconName.Play, Color.White, size = 14.dp)
		}
		Box(Modifier.align(Alignment.BottomCenter).offset(y = 9.dp).fillMaxWidth().height(5.dp).background(color))
	}
}

private val pinPath = PathParser().parsePathString("M20 50s16-15.5 16-28A16 16 0 0 0 4 22c0 12.5 16 28 16 28z").toPath()

/** Teardrop pin that drops in with a squash, plus its little shadow. */
@Composable
fun PinMarker(color: Color, modifier: Modifier = Modifier) {
	val drop = remember { Animatable(0f) }
	LaunchedEffect(Unit) { delay(Random.nextLong(0, 400)); drop.animateTo(1f, spring(dampingRatio = 0.5f, stiffness = 180f)) }
	Box(modifier.size(40.dp, 56.dp), contentAlignment = Alignment.BottomCenter) {
		Canvas(Modifier.size(18.dp, 6.dp).offset(y = 3.dp).graphicsLayer { scaleX = drop.value; scaleY = drop.value }) { drawOval(Color.Black.copy(alpha = 0.25f)) }
		Canvas(Modifier.size(40.dp, 52.dp).graphicsLayer { translationY = (1 - drop.value) * -90.dp.toPx(); alpha = drop.value.coerceIn(0f, 1f) }) {
			val k = size.width / 40f
			val p = Path().apply { addPath(pinPath); transform(androidx.compose.ui.graphics.Matrix().apply { scale(k, k) }) }
			drawPath(p, color)
			drawPath(p, Color.White, style = Stroke(3.dp.toPx()))
			drawCircle(Color.White, 6.5f * k, Offset(20f * k, 21f * k))
		}
	}
}

/** Someone's latest position: face, name tag, a gentle bob; glows while fresh (< 15 min). */
@Composable
private fun PersonMarker(p: LatestLocation) {
	val fresh = TripTime.instant(p.at)?.let { Duration.between(it, Instant.now()) < Duration.ofMinutes(15) } ?: false
	val t = rememberInfiniteTransition(label = "person")
	val bob by t.animateFloat(0f, -5f, infiniteRepeatable(tween(1300), RepeatMode.Reverse), label = "bob")
	val glow by t.animateFloat(0f, 1f, infiniteRepeatable(tween(2000)), label = "glow")
	Column(Modifier.offset(y = bob.dp), horizontalAlignment = Alignment.CenterHorizontally) {
		Text("${p.name} · ${TripTime.ago(p.at)}", style = body(11, FontWeight.ExtraBold), color = Color(0xFF5A4530), maxLines = 1,
			modifier = Modifier.background(Color(0xFFFFFCF0), CircleShape).border(2.dp, Color(0xFFE7DBB8), CircleShape).padding(horizontal = 8.dp, vertical = 2.dp))
		Box(Modifier.padding(top = 3.dp), contentAlignment = Alignment.Center) {
			if (fresh) Box(Modifier.size(40.dp).graphicsLayer { scaleX = 1 + glow * 0.7f; scaleY = 1 + glow * 0.7f; alpha = (1 - glow) * 0.8f }.background(Palette.sea.copy(alpha = 0.5f), CircleShape))
			Avatar(p.name, colorOf(p.color), p.photo, 40.dp, Modifier.graphicsLayer { alpha = if (fresh) 1f else 0.8f }.border(3.5.dp, Color.White, CircleShape))
		}
	}
}
