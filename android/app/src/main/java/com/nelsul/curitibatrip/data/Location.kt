package com.nelsul.curitibatrip.data

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

object LocationOnce {
	fun allowed(context: Context) =
		context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
			context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

	/**
	 * The phone's position now (call after asking for the location permission). Waits up to 20 s for a fresh fix,
	 * then settles for the last known position if it's under 2 minutes old.
	 */
	@SuppressLint("MissingPermission")
	suspend fun current(context: Context): Location {
		if (!allowed(context)) throw ApiError(0, "Sem permissão de localização. Ative nas configurações do app.")
		val client = LocationServices.getFusedLocationProviderClient(context)
		val fresh = withTimeoutOrNull(20_000) {
			val cancel = CancellationTokenSource()
			suspendCancellableCoroutine<Location?> { c ->
				c.invokeOnCancellation { cancel.cancel() }
				client.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cancel.token)
					.addOnSuccessListener { c.resume(it) }
					.addOnFailureListener { c.resume(null) }
			}
		}
		if (fresh != null) return fresh
		val last = suspendCancellableCoroutine<Location?> { c ->
			client.lastLocation.addOnSuccessListener { c.resume(it) }.addOnFailureListener { c.resume(null) }
		}
		return last?.takeIf { System.currentTimeMillis() - it.time < 120_000 }
			?: throw ApiError(0, "Não foi possível pegar sua localização agora. Tente perto de uma janela ou ao ar livre.")
	}
}
