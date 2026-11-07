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
