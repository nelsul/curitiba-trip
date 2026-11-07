package com.nelsul.curitibatrip.data

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.Request
import java.io.IOException

/** Saves an untouched original (HEIC/HEVC with its metadata) into the phone's gallery, in a "Viagem" album. */
object Gallery {
	/** Android 9 and older need the storage permission for this; 10+ doesn't. */
	val needsPermission get() = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

	fun mimeFor(name: String, isVideo: Boolean): String = when (name.substringAfterLast('.', "").lowercase()) {
		"heic", "heif" -> "image/heic"
		"jpg", "jpeg" -> "image/jpeg"
		"png" -> "image/png"
		"webp" -> "image/webp"
		"dng" -> "image/x-adobe-dng"
		"mov" -> "video/quicktime"
		"mp4", "m4v" -> "video/mp4"
		else -> if (isVideo) "video/mp4" else "image/jpeg"
	}

	suspend fun saveOriginal(context: Context, url: String, name: String, isVideo: Boolean) = withContext(Dispatchers.IO) {
		val resolver = context.contentResolver
		val values = ContentValues().apply {
			put(MediaStore.MediaColumns.DISPLAY_NAME, name)
			put(MediaStore.MediaColumns.MIME_TYPE, mimeFor(name, isVideo))
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				put(MediaStore.MediaColumns.RELATIVE_PATH, (if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES) + "/Viagem")
				put(MediaStore.MediaColumns.IS_PENDING, 1)
			}
		}
		val collection = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
		val item = resolver.insert(collection, values) ?: throw IOException("Não foi possível criar o arquivo na galeria.")
		try {
			Api.client.newCall(Request.Builder().url(url).build()).execute().use { r ->
				if (!r.isSuccessful) throw IOException("Download falhou (${r.code}).")
				resolver.openOutputStream(item)!!.use { out -> r.body.byteStream().copyTo(out) }
			}
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				resolver.update(item, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
			}
		} catch (e: Exception) {
			resolver.delete(item, null, null)
			throw e
		}
	}
}
