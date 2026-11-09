package com.nelsul.curitibatrip.data

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import coil3.intercept.Interceptor
import coil3.request.ImageResult
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import okhttp3.Request
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap

/**
 * Photos and videos come from presigned R2 links whose signature changes every day (midnight UTC),
 * but the file behind a path never changes: caches are keyed by the path, so nothing is downloaded twice.
 */
object MediaCache {
	/** The link without its signature. */
	fun stableKey(url: String) = url.substringBefore('?')

	/** Coil: memory and disk cache keys without the signature. */
	class StableKeys : Interceptor {
		override suspend fun intercept(chain: Interceptor.Chain): ImageResult {
			val req = chain.request
			val url = req.data as? String
			if (url == null || !url.startsWith("http") || req.diskCacheKey != null) return chain.proceed()
			val key = stableKey(url)
			return chain.withRequest(req.newBuilder().diskCacheKey(key).memoryCacheKey(key).build()).proceed()
		}
	}
}

/**
 * Videos already watched play from the phone. A copy is saved while one plays on Wi-Fi (never on mobile
 * data, which would download it twice); up to 500 MB, the least recently watched go first.
 */
object VideoCache {
	private lateinit var dir: File
	private lateinit var app: Context
	private val saving = ConcurrentHashMap.newKeySet<String>()
	private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
	private const val LIMIT = 500L * 1024 * 1024

	fun init(context: Context) {
		app = context.applicationContext
		dir = File(context.cacheDir, "videos").apply { mkdirs() }
	}

	/** The local copy when there is one, else the link (and a copy starts downloading on Wi-Fi). */
	fun playable(url: String): Uri {
		if (!url.startsWith("http")) return Uri.parse(url)
		val name = MessageDigest.getInstance("SHA-256").digest(MediaCache.stableKey(url).toByteArray()).joinToString("") { "%02x".format(it) } + ".mp4"
		val file = File(dir, name)
		if (file.exists()) {
			file.setLastModified(System.currentTimeMillis())
			return Uri.fromFile(file)
		}
		if (onWifi() && saving.add(name)) scope.launch {
			try {
				val tmp = File(dir, "$name.part")
				Api.client.newCall(Request.Builder().url(url).build()).execute().use { r ->
					if (!r.isSuccessful) return@use
					tmp.outputStream().use { out -> r.body.byteStream().copyTo(out) }
					tmp.renameTo(file)
				}
				tmp.delete()
				prune()
			} catch (_: Exception) {
			} finally {
				saving.remove(name)
			}
		}
		return Uri.parse(url)
	}

	private fun onWifi(): Boolean {
		val cm = app.getSystemService(ConnectivityManager::class.java)
		val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return false
		return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
	}

	private fun prune() {
		var total = 0L
		dir.listFiles { f -> f.name.endsWith(".mp4") }?.sortedByDescending { it.lastModified() }?.forEach { f ->
			total += f.length()
			if (total > LIMIT) f.delete()
		}
	}
}
