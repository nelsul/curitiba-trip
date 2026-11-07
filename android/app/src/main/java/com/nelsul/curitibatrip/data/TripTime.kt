package com.nelsul.curitibatrip.data

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** All times are shown in Curitiba time, in Portuguese, whatever the phone's settings (same as iOS and web). */
object TripTime {
	val zone: ZoneId = ZoneId.of("America/Sao_Paulo")
	val locale: Locale = Locale.forLanguageTag("pt-BR")
	private val hm = DateTimeFormatter.ofPattern("HH:mm", locale).withZone(zone)
	private val dm = DateTimeFormatter.ofPattern("dd/MM", locale).withZone(zone)
	private val long = DateTimeFormatter.ofPattern("EEEE, d 'de' MMMM", locale)

	fun instant(iso: String): Instant? = runCatching { Instant.parse(iso) }.getOrNull()

	fun time(iso: String): String = instant(iso)?.let { hm.format(it) } ?: ""

	/** "2026-11-13" → "Sexta-feira, 13 de novembro" */
	fun longDay(key: String): String =
		runCatching { LocalDate.parse(key).format(long).replaceFirstChar { it.titlecase(locale) } }.getOrDefault(key)

	/** "agora", "há 5 min", "há 3 h", or "12/11 14:30" (same as the web fmtAgo) */
	fun ago(iso: String): String {
		val t = instant(iso) ?: return ""
		val sec = Duration.between(t, Instant.now()).seconds
		return when {
			sec < 60 -> "agora"
			sec < 3600 -> "há ${sec / 60} min"
			sec < 86400 -> "há ${sec / 3600} h"
			else -> "${dm.format(t)} ${hm.format(t)}"
		}
	}

	/** "2026-11-13" → "sex" */
	fun shortWeekday(key: String): String =
		runCatching { LocalDate.parse(key).format(DateTimeFormatter.ofPattern("EEE", locale)).removeSuffix(".") }.getOrDefault("")

	fun dayKey(iso: String): String = instant(iso)?.atZone(zone)?.toLocalDate()?.toString() ?: ""
}
