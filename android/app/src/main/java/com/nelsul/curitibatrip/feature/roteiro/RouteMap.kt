package com.nelsul.curitibatrip.feature.roteiro

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import coil3.compose.AsyncImage
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.ui.components.pressable
import com.nelsul.curitibatrip.ui.theme.Palette
import com.nelsul.curitibatrip.ui.theme.body
import com.nelsul.curitibatrip.ui.theme.display
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point

/** One numbered stop on the day's map. */
data class RoutePoint(val n: Int, val name: String, val lat: Double, val lng: Double, val photo: String?, val visited: Boolean)

/** Where the person sleeps: the day leaves from there ("start") and/or comes back there ("end"). */
data class RouteHome(val id: String, val name: String, val emoji: String, val label: String, val lat: Double, val lng: Double)

private val cream = Color(0xFFFFFCF0)

/**
 * The day's map (web RouteMap): numbered pins (or the place's photo) and the route by street between them,
 * colored by how you get there; walking legs and straight lines (no street route found) are dashed.
 */
@Composable
fun RouteMap(
	styleJson: String, date: String, points: List<RoutePoint>, modifier: Modifier = Modifier, homes: List<RouteHome> = emptyList(),
	onPick: (Int) -> Unit = {}, onPickHome: (String) -> Unit = {},
) {
	val context = LocalContext.current
	val lifecycle = LocalLifecycleOwner.current.lifecycle
	var map by remember { mutableStateOf<MapLibreMap?>(null) }
	var style by remember { mutableStateOf<Style?>(null) }
	var tick by remember { mutableIntStateOf(0) } // bumps as the camera moves, so the pins follow
	val mapView = remember {
		MapView(context).apply {
			onCreate(null)
			getMapAsync { m ->
				m.uiSettings.isLogoEnabled = false
				m.uiSettings.isRotateGesturesEnabled = false
				m.uiSettings.setAttributionMargins(0, 0, 24, 24)
				(homes.firstOrNull()?.let { LatLng(it.lat, it.lng) } ?: points.firstOrNull()?.let { LatLng(it.lat, it.lng) })
					?.let { m.moveCamera(CameraUpdateFactory.newLatLngZoom(it, 13.0)) }
				m.addOnCameraMoveListener { tick++ }
				m.addOnCameraIdleListener { tick++ }
				m.setStyle(Style.Builder().fromJson(styleJson)) { s ->
					s.addSource(GeoJsonSource("route"))
					s.addLayer(LineLayer("route-casing", "route").withProperties(
						PropertyFactory.lineColor("#fffcf0"), PropertyFactory.lineWidth(8f), PropertyFactory.lineOpacity(0.85f),
						PropertyFactory.lineCap(Property.LINE_CAP_ROUND), PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND)))
					for (dashed in listOf(false, true)) {
						s.addLayer(LineLayer(if (dashed) "route-dashed" else "route", "route").withProperties(
							PropertyFactory.lineColor(Expression.toColor(Expression.get("color"))), PropertyFactory.lineWidth(4.5f),
							PropertyFactory.lineCap(if (dashed) Property.LINE_CAP_BUTT else Property.LINE_CAP_ROUND),
							PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND),
						).apply {
							setFilter(Expression.eq(Expression.get("dashed"), Expression.literal(dashed)))
							if (dashed) setProperties(PropertyFactory.lineDasharray(arrayOf(1f, 1.6f)))
						})
					}
					map = m
					style = s
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
		}
	}
	// show the whole day, then draw the route by street
	LaunchedEffect(style, date, points, homes) {
		val m = map ?: return@LaunchedEffect
		val s = style ?: return@LaunchedEffect
		val all = points.map { LatLng(it.lat, it.lng) } + homes.map { LatLng(it.lat, it.lng) }
		when (all.size) {
			0 -> {}
			1 -> m.moveCamera(CameraUpdateFactory.newLatLngZoom(all[0], 15.0))
			else -> {
				val b = LatLngBounds.Builder().includes(all).build()
				m.moveCamera(CameraUpdateFactory.newLatLngBounds(b, 110, 130, 110, 130))
				if (m.cameraPosition.zoom > 15) m.moveCamera(CameraUpdateFactory.zoomTo(15.0))
			}
		}
		// with "casa" the server also draws the way from and back to where you sleep
		val query = if (homes.isEmpty()) emptyMap() else mapOf("casa" to "1")
		val legs = if (all.size < 2) emptyList() else runCatching { Api.get<DayRoute>("/api/roteiro/days/$date/route", query).legs }.getOrDefault(emptyList())
		val features = legs.mapNotNull { leg ->
			val coords = leg.coordinates.filter { it.size == 2 }.map { Point.fromLngLat(it[0], it[1]) }
			if (coords.size < 2) return@mapNotNull null
			val t = RoteiroTransport.of(leg.transport)
			Feature.fromGeometry(LineString.fromLngLats(coords)).apply {
				addStringProperty("color", "#%06x".format(t.color.toArgb() and 0xFFFFFF))
				addBooleanProperty("dashed", !leg.routed || t == RoteiroTransport.Pe)
			}
		}
		s.getSourceAs<GeoJsonSource>("route")?.setGeoJson(FeatureCollection.fromFeatures(features))
	}

	Box(modifier) {
		AndroidView({ mapView }, Modifier.fillMaxSize())
		val m = map
		if (style != null && m != null) {
			@Suppress("UNUSED_EXPRESSION") tick
			val density = LocalDensity.current
			points.forEach { p ->
				val pt = m.projection.toScreenLocation(LatLng(p.lat, p.lng))
				val size = if (p.photo != null) 54.dp else 38.dp
				val half = with(density) { (size / 2).toPx() }
				Box(
					Modifier
						.offset { IntOffset((pt.x - half).toInt(), (pt.y - half).toInt()) }
						.size(size)
						.pressable({ onPick(p.n) })
						.semantics { contentDescription = "${p.n}. ${p.name}" + if (p.visited) " (já fomos)" else "" },
					contentAlignment = Alignment.Center,
				) { StopPin(p) }
			}
			homes.forEach { h ->
				val pt = m.projection.toScreenLocation(LatLng(h.lat, h.lng))
				val half = with(density) { 22.dp.toPx() }
				Box(
					Modifier
						.offset { IntOffset((pt.x - half).toInt(), (pt.y - half).toInt()) }
						.size(44.dp)
						.pressable({ onPickHome(h.id) })
						.semantics { contentDescription = "${h.label}: ${h.name}" },
					contentAlignment = Alignment.Center,
				) {
					Box(
						Modifier.size(38.dp).shadow(3.dp, RoundedCornerShape(12.dp)).background(Palette.sea, RoundedCornerShape(12.dp))
							.border(3.dp, cream, RoundedCornerShape(12.dp)),
						contentAlignment = Alignment.Center,
					) { Text(h.emoji, style = body(19)) }
				}
			}
		}
	}
}

/** Yellow numbered circle, or the place's photo in a round frame with the number on a badge; ✓ when visited. */
@Composable
private fun StopPin(p: RoutePoint) {
	Box {
		if (p.photo != null) {
			AsyncImage(p.photo, null, contentScale = ContentScale.Crop,
				modifier = Modifier.size(44.dp).shadow(3.dp, CircleShape).clip(CircleShape).border(3.dp, cream, CircleShape))
			Badge("${p.n}", Palette.sun, Palette.onSun, Modifier.align(Alignment.TopStart).offset((-4).dp, (-4).dp))
		} else {
			Box(
				Modifier.size(30.dp).shadow(3.dp, CircleShape).background(if (p.visited) Palette.leaf else Palette.sun, CircleShape).border(3.dp, cream, CircleShape),
				contentAlignment = Alignment.Center,
			) { Text("${p.n}", style = display(14), color = if (p.visited) Palette.onLeaf else Palette.onSun) }
		}
		if (p.visited) Badge("✓", Palette.leaf, Palette.onLeaf, Modifier.align(Alignment.BottomEnd).offset(4.dp, 4.dp))
	}
}

@Composable
private fun Badge(text: String, fill: Color, ink: Color, modifier: Modifier) {
	Box(modifier.size(20.dp).background(fill, CircleShape).border(2.dp, cream, CircleShape), contentAlignment = Alignment.Center) {
		Text(text, style = body(11, FontWeight.ExtraBold), color = ink)
	}
}
