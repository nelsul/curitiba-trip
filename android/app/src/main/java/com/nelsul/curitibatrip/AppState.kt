package com.nelsul.curitibatrip

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.ApiError
import com.nelsul.curitibatrip.data.Me
import com.nelsul.curitibatrip.data.Ok
import com.nelsul.curitibatrip.data.Person
import com.nelsul.curitibatrip.data.TokenStore
import com.nelsul.curitibatrip.data.VerifyResponse
import kotlinx.serialization.encodeToString

/** Who is signed in. The token lives in TokenStore; `me` is refreshed from /api/me on launch. */
class AppState(context: Context) {
	sealed interface Phase {
		data object Loading : Phase
		data object SignedOut : Phase
		data class SignedIn(val me: Me) : Phase
		data class Outdated(val minVersion: String) : Phase
	}

	var phase by mutableStateOf<Phase>(Phase.Loading)
		private set
	var people by mutableStateOf<List<Person>>(emptyList())
		private set
	/** Bumped whenever something changes that the feed shows (likes, comments, edits, deletes, uploads). */
	var feedVersion by mutableIntStateOf(0)
		private set

	val me: Me? get() = (phase as? Phase.SignedIn)?.me

	private val prefs = context.getSharedPreferences("app", Context.MODE_PRIVATE)

	fun feedChanged() { feedVersion++ }
	fun person(id: String) = people.firstOrNull { it.id == id }

	suspend fun restore() {
		if (TokenStore.token == null) { phase = Phase.SignedOut; return }
		try {
			val me: Me = Api.get("/api/me")
			accept(me, me.minAppVersion)
			loadPeople()
		} catch (e: ApiError) {
			if (e.isUnauthorized) {
				TokenStore.clear()
				phase = Phase.SignedOut
				return
			}
			// offline at launch: stay signed in as the last known person; screens show their own "sem conexão" states
			val cached = prefs.getString(ME, null)?.let { runCatching { Api.json.decodeFromString<Me>(it) }.getOrNull() }
			phase = if (cached != null) Phase.SignedIn(cached) else Phase.SignedOut
		}
	}

	suspend fun signedIn(r: VerifyResponse) {
		TokenStore.save(r.token)
		accept(r.user, r.minAppVersion)
		loadPeople()
	}

	suspend fun signOut() {
		runCatching { Api.post<Map<String, String>, Ok>("/api/auth/logout", emptyMap()) }
		TokenStore.clear()
		prefs.edit().remove(ME).apply()
		phase = Phase.SignedOut
	}

	suspend fun reloadMe() {
		runCatching { Api.get<Me>("/api/me") }.getOrNull()?.let { accept(it, it.minAppVersion) }
		loadPeople()
	}

	/** Any 401 from the API means the token is gone (revoked or expired). */
	fun handle(error: Throwable) {
		if ((error as? ApiError)?.isUnauthorized == true) {
			TokenStore.clear()
			phase = Phase.SignedOut
		}
	}

	suspend fun loadPeople() {
		runCatching { Api.get<List<Person>>("/api/people") }.getOrNull()?.let { people = it }
	}

	private fun accept(me: Me, minVersion: String?) {
		prefs.edit().putString(ME, Api.json.encodeToString(me)).apply()
		phase = if (minVersion != null && compareVersions(BuildConfig.VERSION_NAME, minVersion) < 0) Phase.Outdated(minVersion) else Phase.SignedIn(me)
	}

	private companion object {
		const val ME = "me"
		fun compareVersions(a: String, b: String): Int {
			val x = a.split(".").map { it.toIntOrNull() ?: 0 }
			val y = b.split(".").map { it.toIntOrNull() ?: 0 }
			for (i in 0 until maxOf(x.size, y.size)) {
				val c = (x.getOrElse(i) { 0 }).compareTo(y.getOrElse(i) { 0 })
				if (c != 0) return c
			}
			return 0
		}
	}
}

val LocalApp = staticCompositionLocalOf<AppState> { error("AppState not provided") }
