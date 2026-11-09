package com.nelsul.curitibatrip.background

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.nelsul.curitibatrip.MainActivity
import com.nelsul.curitibatrip.R
import com.nelsul.curitibatrip.data.Api
import com.nelsul.curitibatrip.data.Itinerary
import com.nelsul.curitibatrip.data.Person
import com.nelsul.curitibatrip.data.Route
import com.nelsul.curitibatrip.data.TokenStore
import com.nelsul.curitibatrip.data.TripTime
import kotlinx.serialization.Serializable
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.util.concurrent.TimeUnit

/**
 * Local notifications (no push server), the same as iOS:
 * - Novidades: a background check of GET /api/activity every ~15 min ("Bruna postou 3 fotos", comments and likes on my posts).
 * - Roteiro: a reminder 30 min before each stop with a time.
 * - Chegada: "Chegou em …? Fazer check-in" near the next itinerary stops (see BackgroundLocation).
 * Each kind has its own switch in Mais. Tapping one opens the post, or the map's check-in.
 */
object Notifier {
	enum class Kind(val pref: String, val default: Boolean) { Activity("avisos-novidades", true), Itinerary("avisos-roteiro", true), Arrival("avisos-chegada", false) }

	const val CHANNEL_ACTIVITY = "novidades"
	const val CHANNEL_ITINERARY = "roteiro"
	const val CHANNEL_ARRIVAL = "chegada"
	private const val SINCE = "atividade-desde"
	private const val ACTIVITY_WORK = "atividade"

	/** Where a tapped notification wants to go (the shell picks these up). */
	var openRoute by mutableStateOf<Route?>(null)
	var openCheckin by mutableStateOf(0)

	private fun prefs(c: Context) = c.getSharedPreferences("avisos", Context.MODE_PRIVATE)
	fun isOn(c: Context, k: Kind) = prefs(c).getBoolean(k.pref, k.default)

	/** The itinerary was edited: reschedule the 30-min reminders and the arrival areas on this phone. */
	fun itineraryChanged(c: Context) {
		WorkManager.getInstance(c).enqueueUniqueWork("lembretes", ExistingWorkPolicy.REPLACE, OneTimeWorkRequestBuilder<ReminderScheduler>().build())
		BackgroundLocation.refreshAreas(c)
	}

	fun set(c: Context, k: Kind, on: Boolean) {
		prefs(c).edit().putBoolean(k.pref, on).apply()
		when (k) {
			Kind.Activity -> scheduleActivity(c)
			Kind.Itinerary -> WorkManager.getInstance(c).enqueueUniqueWork("lembretes", ExistingWorkPolicy.REPLACE, OneTimeWorkRequestBuilder<ReminderScheduler>().build())
			Kind.Arrival -> BackgroundLocation.refreshAreas(c)
		}
	}

	fun createChannels(c: Context) {
		val nm = c.getSystemService(NotificationManager::class.java)
		nm.createNotificationChannel(NotificationChannel(CHANNEL_ACTIVITY, "Novidades do grupo", NotificationManager.IMPORTANCE_DEFAULT).apply { description = "Fotos, check-ins, comentários e curtidas" })
		nm.createNotificationChannel(NotificationChannel(CHANNEL_ITINERARY, "Lembretes do roteiro", NotificationManager.IMPORTANCE_HIGH).apply { description = "30 minutos antes de cada parada" })
		nm.createNotificationChannel(NotificationChannel(CHANNEL_ARRIVAL, "Chegadas", NotificationManager.IMPORTANCE_HIGH).apply { description = "Chegou num lugar do roteiro? Fazer check-in" })
	}

	/** On launch (signed in): background check and reminders. */
	fun start(c: Context) {
		scheduleActivity(c)
		WorkManager.getInstance(c).enqueueUniqueWork("lembretes", ExistingWorkPolicy.REPLACE, OneTimeWorkRequestBuilder<ReminderScheduler>().build())
	}

	private fun scheduleActivity(c: Context) {
		val wm = WorkManager.getInstance(c)
		if (!isOn(c, Kind.Activity)) return wm.cancelUniqueWork(ACTIVITY_WORK).let {}
		val req = PeriodicWorkRequestBuilder<ActivityWorker>(15, TimeUnit.MINUTES)
			.setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
			.build()
		wm.enqueueUniquePeriodicWork(ACTIVITY_WORK, ExistingPeriodicWorkPolicy.KEEP, req)
	}

	/** What's in the app now was seen; only newer things notify. */
	fun markSeen(c: Context) = prefs(c).edit().putString(SINCE, Instant.now().toString()).apply()

	private fun canPost(c: Context) = Build.VERSION.SDK_INT < 33 ||
		c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

	fun post(c: Context, channel: String, id: String, title: String, body: String, route: Route? = null, checkin: Boolean = false) {
		if (!canPost(c)) return
		val intent = Intent(c, MainActivity::class.java).apply {
			flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
			when (route) {
				is Route.Media -> putExtra("media", route.id)
				is Route.Checkin -> putExtra("checkin", route.id)
				null -> {}
			}
			if (checkin) putExtra("action", "checkin")
		}
		val pi = PendingIntent.getActivity(c, id.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
		val n = NotificationCompat.Builder(c, channel)
			.setSmallIcon(R.drawable.ic_plane)
			.setContentTitle(title)
			.apply { if (body.isNotEmpty()) setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body)) }
			.setContentIntent(pi)
			.setAutoCancel(true)
			.build()
		try { NotificationManagerCompat.from(c).notify(id.hashCode(), n) } catch (_: SecurityException) {}
	}

	/** Asks the server what other people did since the last check and shows it. */
	suspend fun checkActivity(c: Context) {
		if (!isOn(c, Kind.Activity) || TokenStore.token == null) return
		val since = prefs(c).getString(SINCE, null) ?: return markSeen(c)
		val a: Activity = Api.get("/api/activity", mapOf("since" to since))
		val people: List<Person> = runCatching { Api.get<List<Person>>("/api/people") }.getOrDefault(emptyList())
		fun name(id: String) = people.firstOrNull { it.id == id }?.name ?: "Alguém"
		for (p in a.posts) {
			val what = listOfNotNull(
				if (p.photos > 0) "${p.photos} ${if (p.photos == 1) "foto" else "fotos"}" else null,
				if (p.videos > 0) "${p.videos} ${if (p.videos == 1) "vídeo" else "vídeos"}" else null,
			).joinToString(" e ")
			post(c, CHANNEL_ACTIVITY, "post-${p.firstId}", "${name(p.userId)} postou $what", "Veja no diário da viagem.", Route.Media(p.firstId))
		}
		for (k in a.checkins) post(c, CHANNEL_ACTIVITY, "checkin-${k.id}", "${name(k.userId)} fez check-in", k.note.ifEmpty { "Veja onde no mapa." }, Route.Checkin(k.id))
		for (k in a.comments) post(c, CHANNEL_ACTIVITY, "comment-${k.id}", "${name(k.userId)} comentou no seu post", k.body,
			k.mediaId?.let { Route.Media(it) } ?: k.checkinId?.let { Route.Checkin(it) })
		// likes: one line per person
		a.likes.groupBy { it.userId }.forEach { (uid, rows) ->
			val first = rows.first()
			val n = rows.size
			post(c, CHANNEL_ACTIVITY, "likes-$uid-${a.now}", "${name(uid)} curtiu ${if (n == 1) "seu post" else "$n posts seus"} ❤️", "",
				first.mediaId?.let { Route.Media(it) } ?: first.checkinId?.let { Route.Checkin(it) })
		}
		prefs(c).edit().putString(SINCE, a.now).apply()
	}

	/** Stops whose time reads like "9h35" or "14h", as instants in Curitiba time. */
	fun timedStops(it: Itinerary): List<Triple<String, Instant, Itinerary.Stop>> = it.days.flatMap { day ->
		day.stops.mapNotNull { s ->
			val m = Regex("""(\d{1,2})h(\d{2})?""").matchEntire(s.time) ?: return@mapNotNull null
			val t = LocalTime.of(m.groupValues[1].toInt(), m.groupValues[2].ifEmpty { "0" }.toInt())
			Triple(day.date, LocalDate.parse(day.date).atTime(t).atZone(TripTime.zone).toInstant(), s)
		}
	}

	/** "Chegou em …? Fazer check-in", once per place per day. */
	fun arrived(c: Context, placeId: String, name: String) {
		if (!isOn(c, Kind.Arrival)) return
		val key = "chegou-$placeId-${TripTime.dayKey(Instant.now().toString())}"
		if (prefs(c).getBoolean(key, false)) return
		prefs(c).edit().putBoolean(key, true).apply()
		post(c, CHANNEL_ARRIVAL, key, "Chegou em $name? 📍", "Toque para fazer check-in e aparecer no mapa e no diário.", checkin = true)
	}
}

@Serializable
data class Activity(val now: String, val posts: List<Posts> = emptyList(), val checkins: List<Checkin> = emptyList(), val comments: List<Comment> = emptyList(), val likes: List<Like> = emptyList()) {
	@Serializable data class Posts(val userId: String, val photos: Int = 0, val videos: Int = 0, val firstId: String)
	@Serializable data class Checkin(val id: String, val userId: String, val note: String = "")
	@Serializable data class Comment(val id: String, val userId: String, val body: String, val mediaId: String? = null, val checkinId: String? = null)
	@Serializable data class Like(val userId: String, val mediaId: String? = null, val checkinId: String? = null)
}

/** The ~15-minute background check of the group's activity. */
class ActivityWorker(c: Context, p: WorkerParameters) : CoroutineWorker(c, p) {
	override suspend fun doWork(): Result = runCatching { Notifier.checkActivity(applicationContext); Result.success() }.getOrDefault(Result.retry())
}

/** Fetches the itinerary and schedules a reminder 30 min before each upcoming stop. */
class ReminderScheduler(c: Context, p: WorkerParameters) : CoroutineWorker(c, p) {
	override suspend fun doWork(): Result {
		val wm = WorkManager.getInstance(applicationContext)
		wm.cancelAllWorkByTag("lembrete").result.get()
		if (!Notifier.isOn(applicationContext, Notifier.Kind.Itinerary) || TokenStore.token == null) return Result.success()
		val it: Itinerary = runCatching { Api.get<Itinerary>("/api/itinerary") }.getOrNull() ?: return Result.retry()
		for ((day, at, s) in Notifier.timedStops(it)) {
			val delay = Duration.between(Instant.now(), at.minus(Duration.ofMinutes(30)))
			if (delay.isNegative || delay.isZero) continue
			val body = listOfNotNull(s.place?.name?.takeIf { n -> n != s.title }, it.transport[s.transport]?.label, s.note.ifEmpty { null }).joinToString(" · ")
			wm.enqueueUniqueWork("lembrete-$day-${s.time}", ExistingWorkPolicy.REPLACE,
				OneTimeWorkRequestBuilder<ReminderWorker>()
					.setInitialDelay(delay.toMillis(), TimeUnit.MILLISECONDS)
					.setInputData(workDataOf("id" to "roteiro-$day-${s.time}", "title" to "Daqui a 30 min: ${s.title}", "body" to body))
					.addTag("lembrete")
					.build())
		}
		return Result.success()
	}
}

class ReminderWorker(c: Context, p: WorkerParameters) : CoroutineWorker(c, p) {
	override suspend fun doWork(): Result {
		if (Notifier.isOn(applicationContext, Notifier.Kind.Itinerary)) {
			Notifier.post(applicationContext, Notifier.CHANNEL_ITINERARY, inputData.getString("id") ?: "roteiro", inputData.getString("title") ?: "", inputData.getString("body") ?: "")
		}
		return Result.success()
	}
}
