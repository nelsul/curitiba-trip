package com.nelsul.curitibatrip.upload

import android.app.Notification
import android.content.Context
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.ForegroundInfo
import androidx.work.WorkerParameters
import com.nelsul.curitibatrip.R
import com.nelsul.curitibatrip.TripApp
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.ApiError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import okhttp3.MediaType
import okhttp3.Request
import okhttp3.RequestBody
import okio.BufferedSink
import java.io.IOException
import java.io.InputStream

/**
 * Sends one original to R2 with the multipart flow in web/API.md: start the upload, then each part
 * (16 MB, read straight from the gallery file), then "complete". Progress is saved after every part, so a
 * retry (network back, app reopened, phone restarted) only sends what's missing.
 */
class UploadWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
	companion object {
		const val JOB = "job"
		private const val MAX_ATTEMPTS = 8
		private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
		fun cancelOnServer(mediaId: String) { scope.launch { runCatching { Api.delete("/api/uploads/$mediaId") } } }
	}

	@Serializable private data class Start(val name: String, val size: Long, val type: String, val takenAt: String? = null, val takenAtSource: String? = null,
		val lat: Double? = null, val lng: Double? = null, val locationSource: String? = null, val caption: String = "", val clientAssetId: String)
	@Serializable private data class Started(val id: String, val partSize: Long? = null, val partCount: Int? = null, val duplicate: Boolean? = null)
	@Serializable private data class Parts(val parts: List<Int>)
	@Serializable private data class PartUrls(val urls: Map<String, String>)
	@Serializable private data class Done(val n: Int, val etag: String)
	@Serializable private data class Complete(val parts: List<Done>)

	override suspend fun getForegroundInfo(): ForegroundInfo = foreground(0)

	private fun foreground(pct: Int): ForegroundInfo {
		val job = Uploads.get(inputData.getString(JOB) ?: "")
		val n: Notification = NotificationCompat.Builder(applicationContext, TripApp.CHANNEL_UPLOADS)
			.setSmallIcon(R.drawable.ic_upload)
			.setContentTitle("Enviando ${job?.name?.ifEmpty { null } ?: "arquivo"}")
			.setProgress(100, pct, pct == 0)
			.setOngoing(true)
			.setSilent(true)
			.build()
		val nid = (job?.id?.hashCode() ?: 1)
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ForegroundInfo(nid, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC) else ForegroundInfo(nid, n)
	}

	override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
		val id = inputData.getString(JOB) ?: return@withContext Result.failure()
		val job = Uploads.get(id) ?: return@withContext Result.failure()
		if (job.state == UploadJob.State.Done) return@withContext Result.success()
		// big files: show a progress notification and ask Android to keep us running
		if (job.size > 8 * 1024 * 1024) runCatching { setForeground(foreground(0)) }
		try {
			run(id)
			Result.success()
		} catch (e: ApiError) {
			Uploads.setSent(id, null)
			when {
				e.status == 0 || e.status >= 500 -> retryOrFail(id, "Conexão instável. Toque em “Tentar de novo”.")
				e.status == 401 -> fail(id, "Sua sessão expirou. Entre de novo e toque em “Tentar de novo”.")
				e.status == 409 -> { finish(id); Result.success() } // the server already has it
				else -> fail(id, e.message)
			}
		} catch (e: IOException) {
			Log.w("Upload", "part failed: ${e.message}")
			Uploads.setSent(id, null)
			retryOrFail(id, "Conexão instável. Toque em “Tentar de novo”.")
		} catch (e: SecurityException) {
			fail(id, "O app perdeu o acesso a este arquivo. Escolha de novo.")
		}
	}

	private fun retryOrFail(id: String, message: String) =
		if (runAttemptCount + 1 >= MAX_ATTEMPTS) fail(id, message) else Result.retry()

	private fun fail(id: String, message: String): Result {
		Uploads.update(id) { it.copy(state = UploadJob.State.Failed, error = message) }
		return Result.failure()
	}

	private suspend fun run(id: String) {
		var job = Uploads.get(id)!!
		if (job.mediaId == null) {
			val started: Started = Api.post("/api/uploads", Start(job.name, job.size, job.mime, job.takenAt, if (job.takenAt != null) "exif" else null,
				job.lat, job.lng, job.locationSource, job.caption, job.assetId))
			if (started.duplicate == true) {
				Uploads.update(id) { it.copy(mediaId = started.id, state = UploadJob.State.Done, duplicate = true) }
				Uploads.arrived()
				return
			}
			Uploads.update(id) { it.copy(mediaId = started.id, partSize = started.partSize ?: 0, partCount = started.partCount ?: 0, state = UploadJob.State.Uploading) }
			job = Uploads.get(id)!!
		} else Uploads.update(id) { it.copy(state = UploadJob.State.Uploading, error = null) }

		val missing = (1..job.partCount).filter { it !in job.etags }
		var urls = emptyMap<Int, String>()
		for (n in missing) {
			if (n !in urls) urls = missing.filter { it >= n }.take(50).let { batch ->
				Api.post<Parts, PartUrls>("/api/uploads/${job.mediaId}/parts", Parts(batch)).urls.mapKeys { it.key.toInt() }
			}
			val start = (n - 1) * job.partSize
			val length = minOf(job.partSize, job.size - start)
			val done = Uploads.get(id)!!.etags.size * job.partSize
			val etag = putPart(urls.getValue(n), Uri.parse(job.sourceUri), start, length) { bytes ->
				val sent = minOf(job.size, done + bytes)
				Uploads.setSent(id, sent)
			}
			Uploads.update(id) { it.copy(etags = it.etags + (n to etag)) }
			if (job.size > 8 * 1024 * 1024) runCatching { setForeground(foreground(((done + length) * 100 / job.size).toInt())) }
		}
		finish(id)
	}

	private suspend fun finish(id: String) {
		val job = Uploads.get(id)!!
		Uploads.update(id) { it.copy(state = UploadJob.State.Finishing) }
		try {
			Api.post<Complete, kotlinx.serialization.json.JsonObject>("/api/uploads/${job.mediaId}/complete", Complete(job.etags.toSortedMap().map { Done(it.key, it.value) }))
		} catch (e: ApiError) {
			if (e.status != 409) throw e
		}
		Uploads.update(id) { it.copy(state = UploadJob.State.Done, error = null) }
		Uploads.setSent(id, null)
		Uploads.arrived()
	}

	/** PUTs one part, read straight from the gallery file (no copy on disk), and returns R2's ETag. */
	private fun putPart(url: String, source: Uri, start: Long, length: Long, progress: (Long) -> Unit): String {
		val body = object : RequestBody() {
			override fun contentType(): MediaType? = null
			override fun contentLength() = length
			override fun writeTo(sink: BufferedSink) {
				applicationContext.contentResolver.openInputStream(source)!!.use { input ->
					input.skipFully(start)
					val buf = ByteArray(64 * 1024)
					var left = length
					var sent = 0L
					while (left > 0) {
						val r = input.read(buf, 0, minOf(buf.size.toLong(), left).toInt())
						if (r < 0) throw IOException("O arquivo mudou durante o envio.")
						sink.write(buf, 0, r)
						left -= r
						sent += r
						progress(sent)
					}
				}
			}
		}
		Api.client.newCall(Request.Builder().url(url).put(body).build()).execute().use { r ->
			if (!r.isSuccessful) throw if (r.code == 403 || r.code >= 500) IOException("R2 ${r.code}") else ApiError(r.code, "O servidor de arquivos recusou (${r.code}).")
			return r.header("ETag") ?: throw IOException("Sem ETag")
		}
	}

	private fun InputStream.skipFully(n: Long) {
		var left = n
		while (left > 0) {
			val s = skip(left)
			if (s <= 0) { if (read() < 0) throw IOException("Arquivo menor que o esperado."); left-- } else left -= s
		}
	}
}
