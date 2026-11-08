package com.nelsul.curitibatrip.background

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.util.Log
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.Itinerary
import com.nelsul.curitibatrip.data.TokenStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject
import java.time.Duration
import java.time.Instant

/**
 * "Meu caminho com o app fechado" (off by default, switch in Mais): battery-friendly location updates delivered
 * to a receiver even when the app is closed, queued with their real times and sent to /api/locations/batch, so
 * each day's trail draws itself. Also watches areas around the next itinerary stops ("Chegou? Fazer check-in").
 * Needs "Permitir o tempo todo".
 */
object BackgroundLocation {
	private const val PREF = "localizacao-segundo-plano"
	private const val QUEUE = "localizacao-fila"
	private const val AREAS = "areas"
	private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

	@Serializable data class Queued(val lat: Double, val lng: Double, val accuracy: Double, val at: String)
	@Serializable data class Area(val id: String, val name: String, val lat: Double, val lng: Double)

	private fun prefs(c: Context) = c.getSharedPreferences("localizacao", Context.MODE_PRIVATE)
	fun isOn(c: Context) = prefs(c).getBoolean(PREF, false)

	fun hasAlways(c: Context) = Build.VERSION.SDK_INT < 29 ||
		c.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
	private fun hasForeground(c: Context) = c.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
		c.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

	fun set(c: Context, on: Boolean) {
		prefs(c).edit().putBoolean(PREF, on).apply()
		if (on) start(c) else stop(c)
	}

	private fun pending(c: Context, action: String) = PendingIntent.getBroadcast(
		c, action.hashCode(), Intent(c, LocationReceiver::class.java).setAction(action),
		PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE, // the system adds the locations to it
	)

	/** Starts (or restarts, after a reboot) the light updates and the arrival areas, if allowed. */
	@SuppressLint("MissingPermission")
	fun start(c: Context) {
		if (!isOn(c) || !hasForeground(c) || !hasAlways(c)) return
		val req = LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 5 * 60_000)
			.setMinUpdateDistanceMeters(100f)
			.setMaxUpdateDelayMillis(15 * 60_000) // batched: fewer wake-ups
			.build()
		LocationServices.getFusedLocationProviderClient(c).requestLocationUpdates(req, pending(c, LocationReceiver.UPDATES))
		refreshAreas(c)
	}

	fun stop(c: Context) {
		LocationServices.getFusedLocationProviderClient(c).removeLocationUpdates(pending(c, LocationReceiver.UPDATES))
		LocationServices.getGeofencingClient(c).removeGeofences(pending(c, LocationReceiver.AREAS))
	}

	/** Watches the next stops of the itinerary (up to 15 areas of 150 m). */
	@SuppressLint("MissingPermission")
	fun refreshAreas(c: Context) {
		val geo = LocationServices.getGeofencingClient(c)
		geo.removeGeofences(pending(c, LocationReceiver.AREAS))
		if (!isOn(c) || !hasAlways(c) || !Notifier.isOn(c, Notifier.Kind.Arrival) || TokenStore.token == null) {
			prefs(c).edit().remove(AREAS).apply()
			return
		}
		scope.launch {
			val it = runCatching { Api.get<Itinerary>("/api/itinerary") }.getOrNull() ?: return@launch
			val areas = Notifier.timedStops(it)
				.filter { (_, at, s) -> Duration.between(Instant.now(), at) > Duration.ofHours(-3) && s.place != null }
				.map { (_, _, s) -> s.place!! }
				.distinctBy { p -> p.id }
				.take(15)
				.map { p -> Area(p.id, p.name, p.lat, p.lng) }
			prefs(c).edit().putString(AREAS, Api.json.encodeToString(areas)).apply()
			if (areas.isEmpty()) return@launch
			val req = GeofencingRequest.Builder()
				.setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER) // already there counts
				.addGeofences(areas.map { a ->
					Geofence.Builder().setRequestId(a.id).setCircularRegion(a.lat, a.lng, 150f)
						.setExpirationDuration(Geofence.NEVER_EXPIRE).setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER).build()
				})
				.build()
			geo.addGeofences(req, pending(c, LocationReceiver.AREAS)).addOnFailureListener { e -> Log.w("Location", "areas: ${e.message}") }
		}
	}

	fun areas(c: Context): List<Area> = prefs(c).getString(AREAS, null)?.let { runCatching { Api.json.decodeFromString<List<Area>>(it) }.getOrNull() } ?: emptyList()

	/** Area entries can be slow or missed, so every precise position is also checked against them. */
	fun checkArrival(c: Context, l: Location) {
		if (!l.hasAccuracy() || l.accuracy > 100) return
		for (a in areas(c)) {
			val d = FloatArray(1)
			Location.distanceBetween(l.latitude, l.longitude, a.lat, a.lng, d)
			if (d[0] <= 150) Notifier.arrived(c, a.id, a.name)
		}
	}

	@Synchronized
	fun enqueue(c: Context, points: List<Location>) {
		val p = prefs(c)
		val q = p.getString(QUEUE, null)?.let { runCatching { Api.json.decodeFromString<List<Queued>>(it) }.getOrNull() }.orEmpty().toMutableList()
		points.filter { it.hasAccuracy() && it.accuracy <= 500 }.forEach { q += Queued(it.latitude, it.longitude, it.accuracy.toDouble(), Instant.ofEpochMilli(it.time).toString()) }
		p.edit().putString(QUEUE, Api.json.encodeToString(q.takeLast(500))).apply()
		WorkManager.getInstance(c).enqueueUniqueWork("localizacao-envio", ExistingWorkPolicy.KEEP,
			OneTimeWorkRequestBuilder<LocationBatchWorker>().setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build())
	}

	/** Sends the queued points (the server drops ones older than 48 h). */
	suspend fun flush(c: Context): Boolean {
		val p = prefs(c)
		val raw = synchronized(this) { p.getString(QUEUE, null) } ?: return true
		val q = runCatching { Api.json.decodeFromString<List<Queued>>(raw) }.getOrNull().orEmpty()
		if (q.isEmpty() || TokenStore.token == null) return true
		return try {
			Api.post<List<Queued>, JsonObject>("/api/locations/batch", q)
			synchronized(this) {
				// keep anything that arrived while sending
				val now = p.getString(QUEUE, null)?.let { runCatching { Api.json.decodeFromString<List<Queued>>(it) }.getOrNull() }.orEmpty()
				p.edit().putString(QUEUE, Api.json.encodeToString(now.drop(q.size))).apply()
			}
			true
		} catch (e: Exception) {
			Log.w("Location", "batch failed, will retry: ${e.message}")
			false
		}
	}
}

/** Receives background positions and area entries, even with the app closed. */
class LocationReceiver : BroadcastReceiver() {
	companion object {
		const val UPDATES = "com.nelsul.curitibatrip.LOCATION_UPDATES"
		const val AREAS = "com.nelsul.curitibatrip.AREAS"
	}

	override fun onReceive(c: Context, intent: Intent) {
		when (intent.action) {
			UPDATES -> LocationResult.extractResult(intent)?.locations?.takeIf { it.isNotEmpty() }?.let { points ->
				BackgroundLocation.enqueue(c, points)
				BackgroundLocation.checkArrival(c, points.last())
			}
			AREAS -> {
				val e = GeofencingEvent.fromIntent(intent) ?: return
				if (e.hasError() || e.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) return
				val areas = BackgroundLocation.areas(c)
				e.triggeringGeofences?.forEach { g -> areas.firstOrNull { it.id == g.requestId }?.let { a -> Notifier.arrived(c, a.id, a.name) } }
			}
		}
	}
}

class LocationBatchWorker(c: Context, p: WorkerParameters) : CoroutineWorker(c, p) {
	override suspend fun doWork(): Result {
		val ok = BackgroundLocation.flush(applicationContext)
		// a wake-up is a good moment to look for news too
		runCatching { Notifier.checkActivity(applicationContext) }
		return if (ok) Result.success() else Result.retry()
	}
}

/** Restarts background location and the arrival areas after a reboot or an app update. */
class BootReceiver : BroadcastReceiver() {
	override fun onReceive(c: Context, intent: Intent) {
		if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) BackgroundLocation.start(c)
	}
}
