import Foundation

/// All times are shown in Curitiba time (America/Sao_Paulo), in Portuguese, whatever the phone's settings.
enum TripTime {
	static let zone = TimeZone(identifier: "America/Sao_Paulo")!
	static let locale = Locale(identifier: "pt_BR")

	// Value-type parse styles: thread-safe under Swift 6 strict concurrency (unlike ISO8601DateFormatter)
	private static let iso = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
	private static let isoNoFraction = Date.ISO8601FormatStyle()

	static func date(_ s: String) -> Date? { (try? iso.parse(s)) ?? (try? isoNoFraction.parse(s)) }

	static func time(_ s: String) -> String {
		guard let d = date(s) else { return "" }
		return d.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: zone))
	}

	/// "2026-11-13" → "Sexta-feira, 13 de novembro"
	static func longDay(_ key: String) -> String {
		guard let d = date("\(key)T12:00:00.000-03:00") else { return key }
		var style = Date.FormatStyle(locale: locale, timeZone: zone)
		style = style.weekday(.wide).day().month(.wide)
		let s = d.formatted(style)
		return s.prefix(1).uppercased() + s.dropFirst()
	}
}

extension TripTime {
	/// "agora", "há 5 min", "há 3 h", or "12/11 14:30" (same as the web fmtAgo)
	static func ago(_ s: String) -> String {
		guard let d = date(s) else { return "" }
		let sec = Int(Date().timeIntervalSince(d))
		if sec < 60 { return "agora" }
		if sec < 3600 { return "há \(sec / 60) min" }
		if sec < 86400 { return "há \(sec / 3600) h" }
		return d.formatted(Date.FormatStyle(locale: locale, timeZone: zone).day(.twoDigits).month(.twoDigits)) + " " + time(s)
	}

	static func dayKey(_ s: String) -> String {
		guard let d = date(s) else { return "" }
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = zone
		let c = cal.dateComponents([.year, .month, .day], from: d)
		return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
	}
}

extension TripTime {
	/// "12/11 14:30" in Curitiba time.
	static func short(_ d: Date) -> String {
		d.formatted(Date.FormatStyle(locale: locale, timeZone: zone).day(.twoDigits).month(.twoDigits).hour().minute())
	}
}
