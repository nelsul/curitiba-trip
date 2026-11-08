package com.nelsul.curitibatrip.feature.mapa

import android.content.Context
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.ApiError
import java.io.File

/**
 * The island night style (GET /api/map-style.json). Fetched with the app's token and handed to MapLibre as JSON,
 * so the token never goes to the tile servers. Cached for an hour, and kept for offline use.
 */
object MapStyle {
	private const val MAX_AGE = 3600_000L

	suspend fun json(context: Context): String {
		val file = File(context.cacheDir, "map-style.json")
		if (file.exists() && System.currentTimeMillis() - file.lastModified() < MAX_AGE) return file.readText()
		return try {
			Api.execute(Api.request("GET", "/api/map-style.json")).also { file.writeText(it) }
		} catch (e: ApiError) {
			if (e.isUnauthorized || !file.exists()) throw ApiError(e.status, if (e.status == 0) "Sem conexão para carregar o mapa." else e.message)
			file.readText() // offline: the older copy still works
		}
	}
}
