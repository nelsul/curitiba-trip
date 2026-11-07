package com.nelsul.curitibatrip.upload

import android.content.ContentUris
import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.exifinterface.media.ExifInterface
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/** A picked photo/video, with what we could read about it. */
data class PickedMedia(
	val pickerUri: Uri,
	/** The MediaStore original (with GPS) when we have gallery access; otherwise the picker's copy. */
	val sourceUri: Uri,
	val assetId: String,
	val name: String,
	val mime: String,
	val size: Long,
	val isVideo: Boolean,
	val takenAt: Instant?,
	val lat: Double?,
	val lng: Double?,
) {
	val hasLocation get() = lat != null && lng != null
}

object MediaReader {
	/**
	 * The system photo picker hands out copies with the GPS removed. For local items its URI ends with the
	 * MediaStore id, so with gallery access (+ ACCESS_MEDIA_LOCATION) we read and upload the untouched original.
	 */
	fun read(context: Context, picked: Uri): PickedMedia {
		val resolver = context.contentResolver
		val pickerMime = resolver.getType(picked) ?: ""
		val isVideo = pickerMime.startsWith("video/")
		val original = picked.lastPathSegment?.toLongOrNull()?.let { id ->
			val base = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
			val uri = ContentUris.withAppendedId(base, id)
			val full = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) runCatching { MediaStore.setRequireOriginal(uri) }.getOrDefault(uri) else uri
			// only usable if we really may open it
			full.takeIf { runCatching { resolver.openInputStream(it)?.close(); true }.getOrDefault(false) }
		}
		val source = original ?: picked

		var name = "arquivo"
		var size = 0L
		resolver.query(source, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { c ->
			if (c.moveToFirst()) {
				c.getString(0)?.let { name = it }
				size = c.getLong(1)
			}
		}
		val mime = resolver.getType(source)?.takeIf { it != "application/octet-stream" } ?: pickerMime.ifEmpty { if (isVideo) "video/mp4" else "image/jpeg" }

		var takenAt: Instant? = null
		var lat: Double? = null
		var lng: Double? = null
		if (isVideo) {
			runCatching {
				MediaMetadataRetriever().apply { setDataSource(context, source) }.use { r ->
					// "+12.3456-045.6789/" (ISO 6709)
					r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_LOCATION)?.let { s ->
						Regex("""([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)""").find(s)?.let { m -> lat = m.groupValues[1].toDouble(); lng = m.groupValues[2].toDouble() }
					}
					r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE)?.let { d ->
						takenAt = runCatching { LocalDateTime.parse(d.substringBefore('.'), DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss")).toInstant(ZoneOffset.UTC) }.getOrNull()
					}
				}
			}
		} else {
			runCatching {
				resolver.openInputStream(source)?.use { input ->
					val exif = ExifInterface(input)
					exif.latLong?.let { (a, b) -> if (!(a == 0.0 && b == 0.0)) { lat = a; lng = b } }
					takenAt = exif.dateTimeOriginal?.let { Instant.ofEpochMilli(it) } ?: exif.dateTime?.let { Instant.ofEpochMilli(it) }
				}
			}
		}
		if (takenAt == null) {
			// the gallery's own date
			runCatching {
				resolver.query(source, arrayOf(MediaStore.MediaColumns.DATE_TAKEN), null, null, null)?.use { c ->
					if (c.moveToFirst() && !c.isNull(0)) takenAt = Instant.ofEpochMilli(c.getLong(0)).takeIf { it.toEpochMilli() > 0 }
				}
			}
		}
		return PickedMedia(picked, source, assetId = picked.lastPathSegment ?: picked.toString(), name, mime, size, isVideo, takenAt, lat, lng)
	}
}
