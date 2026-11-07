package com.nelsul.curitibatrip.data

import com.nelsul.curitibatrip.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

class ApiError(val status: Int, override val message: String) : Exception(message) {
	val isUnauthorized get() = status == 401
}

/** Talks to the web app's JSON API (web/API.md). The server's error messages are already in Portuguese. */
object Api {
	val base: String = BuildConfig.API_BASE_URL.trimEnd('/')
	val json = Json { ignoreUnknownKeys = true; explicitNulls = false; coerceInputValues = true; encodeDefaults = false }
	val client: OkHttpClient = OkHttpClient.Builder()
		.connectTimeout(15, TimeUnit.SECONDS)
		.readTimeout(30, TimeUnit.SECONDS)
		.build()
	private val jsonType = "application/json".toMediaType()

	/** Builds a request with auth and the app version (also used by the uploader). */
	fun request(method: String, path: String, query: Map<String, String?> = emptyMap(), body: RequestBody? = null): Request {
		val url = (base + path).toHttpUrl().newBuilder().apply { query.forEach { (k, v) -> if (v != null) addQueryParameter(k, v) } }.build()
		return Request.Builder()
			.url(url)
			.method(method, body ?: if (method == "POST" || method == "PUT" || method == "PATCH") ByteArray(0).toRequestBody() else null)
			.header("accept", "application/json")
			.header("x-app-version", BuildConfig.VERSION_NAME)
			.apply { TokenStore.token?.let { header("authorization", "Bearer $it") } }
			.build()
	}

	suspend fun execute(req: Request): String = withContext(Dispatchers.IO) {
		val response = try {
			client.newCall(req).execute()
		} catch (e: IOException) {
			android.util.Log.w("Api", "${req.method} ${req.url.encodedPath} failed: ${e.message}")
			throw ApiError(0, "Sem conexão. Tente de novo em instantes.")
		}
		response.use { r ->
			val text = r.body.string()
			if (!r.isSuccessful) {
				val message = runCatching { json.parseToJsonElement(text).jsonObject["message"]?.jsonPrimitive?.content }.getOrNull()
				throw ApiError(r.code, message ?: "Algo deu errado (${r.code}).")
			}
			text
		}
	}

	suspend inline fun <reified T> get(path: String, query: Map<String, String?> = emptyMap()): T =
		json.decodeFromString(execute(request("GET", path, query)))

	suspend inline fun <reified B, reified T> post(path: String, body: B): T =
		json.decodeFromString(execute(request("POST", path, body = jsonBody(body))))

	suspend inline fun <reified B, reified T> patch(path: String, body: B): T =
		json.decodeFromString(execute(request("PATCH", path, body = jsonBody(body))))

	suspend fun delete(path: String) { execute(request("DELETE", path)) }

	/** Raw binary body (profile photos, check-in map pictures). */
	suspend inline fun <reified T> put(path: String, data: ByteArray, contentType: String): T =
		json.decodeFromString(execute(request("PUT", path, body = data.toRequestBody(contentType.toMediaType()))))

	inline fun <reified B> jsonBody(body: B): RequestBody = json.encodeToString(body).toRequestBody("application/json".toMediaType())
}
