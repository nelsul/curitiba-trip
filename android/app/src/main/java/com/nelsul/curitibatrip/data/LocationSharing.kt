package com.nelsul.curitibatrip.data

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.os.Looper
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * "Compartilhar local" (web location.svelte.ts): while on and the app is open, the phone's position goes to the
 * group map. Same throttle as the web and iOS: skip points within 30 m and 3 min of the last one sent, and very
 * imprecise ones.
 */
object LocationSharing {
	private const val PREF = "compartilhar-localizacao"
	private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
	private lateinit var appContext: Context

	var sharing by mutableStateOf(false)
		private set
	var last by mutableStateOf<Location?>(null)
		private set
	var error by mutableStateOf<String?>(null)
	private var lastSent: Location? = null

	private val callback = object : LocationCallback() {
		override fun onLocationResult(r: LocationResult) {
			val l = r.lastLocation ?: return
			last = l
			error = null
			if (sharing) send(l)
		}
	}

	fun init(context: Context) {
		appContext = context.applicationContext
	}

	private val prefs get() = appContext.getSharedPreferences("app", Context.MODE_PRIVATE)

	/** Turns sharing back on if it was on last time (when the app comes to the front). */
	fun resume() { if (prefs.getBoolean(PREF, false)) start() }

	@SuppressLint("MissingPermission")
	fun start() {
		if (!LocationOnce.allowed(appContext)) {
			error = "Sem permissão de localização. Ative nas configurações do app."
			sharing = false
			return
		}
		sharing = true
		error = null
		prefs.edit().putBoolean(PREF, true).apply()
		val req = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 15_000).setMinUpdateDistanceMeters(20f).build()
		LocationServices.getFusedLocationProviderClient(appContext).requestLocationUpdates(req, callback, Looper.getMainLooper())
		last?.let { send(it, force = true) }
	}

	fun stop() {
		sharing = false
		prefs.edit().putBoolean(PREF, false).apply()
		pause()
	}

	/** Leaving the app: live updates stop (the background mode in Mais keeps the light ones). */
	fun pause() { LocationServices.getFusedLocationProviderClient(appContext).removeLocationUpdates(callback) }

	private fun send(l: Location, force: Boolean = false) {
		if (!l.hasAccuracy() || l.accuracy > 500) return
		val prev = lastSent
		if (!force && prev != null && prev.distanceTo(l) < 30 && l.time - prev.time < 180_000) return
		lastSent = l
		scope.launch {
			try {
				Api.post<PositionBody, Ok>("/api/locations", PositionBody(l.latitude, l.longitude, l.accuracy.toDouble()))
			} catch (e: Exception) {
				lastSent = null // try again with the next update
				Log.w("Location", "could not send position: ${e.message}")
			}
		}
	}
}
