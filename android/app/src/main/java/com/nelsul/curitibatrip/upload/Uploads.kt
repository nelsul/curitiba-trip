package com.nelsul.curitibatrip.upload

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.nelsul.curitibatrip.data.Api
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.serialization.Serializable
import java.io.File
import java.util.UUID
import java.util.concurrent.TimeUnit

/** One photo or video on its way to the diary. Saved to disk so uploads survive the app being closed. */
@Serializable
data class UploadJob(
	val id: String,
	/** What we read the file from: the MediaStore original when we may, otherwise the picker's copy. */
	val sourceUri: String,
	/** Stable id of the gallery item (the server refuses a second copy of the same one). */
	val assetId: String,
	val caption: String = "",
	val name: String = "",
	val mime: String = "",
	val size: Long = 0,
	val isVideo: Boolean = false,
	val takenAt: String? = null,
	val lat: Double? = null,
	val lng: Double? = null,
	/** "device-library" (the photo's own GPS) or "device" (the phone's position when picked). */
	val locationSource: String? = null,
	val state: State = State.Waiting,
	val mediaId: String? = null,
	val partSize: Long = 0,
	val partCount: Int = 0,
	val etags: Map<Int, String> = emptyMap(),
	val error: String? = null,
	val duplicate: Boolean = false,
	/** Send the original only on Wi-Fi (a low-res preview goes to the diary first). */
	val wifiOnly: Boolean = false,
	val previewSent: Boolean = false,
) {
	enum class State { Waiting, Uploading, Finishing, Done, Failed }
	val active get() = state == State.Waiting || state == State.Uploading || state == State.Finishing
}

/** All upload jobs, persisted as JSON in the app's files; the workers update them as they go. */
object Uploads {
	private lateinit var file: File
	private lateinit var work: WorkManager
	private val _jobs = MutableStateFlow<List<UploadJob>>(emptyList())
	val jobs: StateFlow<List<UploadJob>> = _jobs.asStateFlow()
	/** Bytes in flight per job (not saved). */
	private val _sent = MutableStateFlow<Map<String, Long>>(emptyMap())
	val sent: StateFlow<Map<String, Long>> = _sent.asStateFlow()
	/** Bumped when a file reaches the server, so the feed can refresh. */
	private val _arrivals = MutableStateFlow(0)
	val arrivals: StateFlow<Int> = _arrivals.asStateFlow()

	fun init(context: Context) {
		file = File(context.filesDir, "uploads.json")
		work = WorkManager.getInstance(context)
		_jobs.value = runCatching { Api.json.decodeFromString<List<UploadJob>>(file.readText()) }.getOrDefault(emptyList())
		prefs = context.getSharedPreferences("envio", Context.MODE_PRIVATE)
		wifiOnly.value = prefs.getBoolean("envio-so-wifi", false)
	}

	@Synchronized
	private fun save() { runCatching { file.writeText(Api.json.encodeToString(_jobs.value)) } }

	fun get(id: String) = _jobs.value.firstOrNull { it.id == id }

	@Synchronized
	fun update(id: String, change: (UploadJob) -> UploadJob) {
		_jobs.update { list -> list.map { if (it.id == id) change(it) else it } }
		save()
	}

	fun setSent(id: String, bytes: Long?) = _sent.update { if (bytes == null) it - id else it + (id to bytes) }

	fun arrived() = _arrivals.update { it + 1 }

	fun add(job: UploadJob) {
		// the same gallery item already on its way or sent: the server would refuse a copy anyway
		if (_jobs.value.any { it.assetId == job.assetId && it.state != UploadJob.State.Failed }) return
		synchronized(this) {
			_jobs.update { list -> list.filterNot { it.assetId == job.assetId } + job }
			save()
		}
		enqueue(job.id)
	}

	/** "Enviar agora": stop waiting for Wi-Fi and send this one over any connection. */
	fun sendNow(id: String) {
		update(id) { it.copy(wifiOnly = false) }
		enqueue(id)
	}

	fun retry(id: String) {
		update(id) { it.copy(state = UploadJob.State.Waiting, error = null) }
		enqueue(id)
	}

	fun cancel(id: String) {
		val job = get(id) ?: return
		work.cancelUniqueWork(id)
		synchronized(this) { _jobs.update { it.filterNot { j -> j.id == id } }; save() }
		setSent(id, null)
		if (job.mediaId != null && job.state != UploadJob.State.Done) UploadWorker.cancelOnServer(job.mediaId)
	}

	fun clearFinished() = synchronized(this) { _jobs.update { it.filterNot { j -> j.state == UploadJob.State.Done } }; save() }

	/** One unique work per file; WorkManager keeps it across app restarts and retries it when the network returns. */
	fun enqueue(id: String) {
		// "só no Wi-Fi": the preview goes first (any network); the worker then waits for an unmetered one
		val wifiOnly = get(id)?.let { it.wifiOnly && it.previewSent } == true
		val req = OneTimeWorkRequestBuilder<UploadWorker>()
			.setInputData(workDataOf(UploadWorker.JOB to id))
			.setConstraints(Constraints.Builder().setRequiredNetworkType(if (wifiOnly) NetworkType.UNMETERED else NetworkType.CONNECTED).build())
			.setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.SECONDS)
			.setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
			.addTag("upload")
			.build()
		work.enqueueUniqueWork(id, ExistingWorkPolicy.REPLACE, req)
	}

	/** "Enviar só no Wi-Fi" (Enviar screen), remembered. */
	private lateinit var prefs: android.content.SharedPreferences
	val wifiOnly = MutableStateFlow(false)
	fun setWifiOnly(on: Boolean) { wifiOnly.value = on; prefs.edit().putBoolean("envio-so-wifi", on).apply() }

	fun newId() = UUID.randomUUID().toString()
}
