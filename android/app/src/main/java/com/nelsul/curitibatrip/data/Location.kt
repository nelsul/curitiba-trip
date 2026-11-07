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
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

object LocationOnce {
	fun allowed(context: Context) =
		context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
			context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

	/** The phone's position now (call after asking for the location permission). */
	@SuppressLint("MissingPermission")
	suspend fun current(context: Context): Location {
		if (!allowed(context)) throw ApiError(0, "Sem permissão de localização. Ative nas configurações do app.")
		val client = LocationServices.getFusedLocationProviderClient(context)
		val cancel = CancellationTokenSource()
		return suspendCancellableCoroutine { c ->
			c.invokeOnCancellation { cancel.cancel() }
			client.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cancel.token)
				.addOnSuccessListener { l -> if (l != null) c.resume(l) else c.resumeWithException(ApiError(0, "Não foi possível pegar sua localização agora.")) }
				.addOnFailureListener { c.resumeWithException(ApiError(0, "Não foi possível pegar sua localização agora.")) }
		}
	}
}
