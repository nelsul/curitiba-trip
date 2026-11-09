import SwiftUI

/// One day's forecast (GET /api/weather): the summary and an hour-by-hour strip from 6h, scrolled to now on today.
struct WeatherCard: View {
	let day: WeatherDay

	private var hours: [WeatherHour] { day.hours.filter { (Int($0.time.prefix(2)) ?? 0) >= 6 } }

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 10) {
				Icon(Weather.icon(day.kind), size: 34).foregroundStyle(Weather.color(day.max))
				VStack(alignment: .leading, spacing: 0) {
					Text("\(day.min)° a \(day.max)°").font(.display(19)).foregroundStyle(Color.ink)
					Text(Weather.label(day.kind) + (day.rain >= 20 ? " · \(day.rain)% de chuva" : "")).font(.text(13)).foregroundStyle(Color.muted)
				}
			}
			ScrollViewReader { proxy in
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 4) {
						ForEach(hours, id: \.time) { h in
							VStack(spacing: 2) {
								Text(h.time.replacingOccurrences(of: ":00", with: "h")).font(.text(12, .extraBold)).foregroundStyle(Color.muted)
								Icon(Weather.icon(h.kind), size: 20).foregroundStyle(Weather.color(h.temp))
								Text("\(h.temp)°").font(.text(15, .extraBold)).foregroundStyle(Color.ink)
								Text("\(h.rain)%").font(.text(11, .extraBold)).foregroundStyle(Color.sky).opacity(h.rain >= 20 ? 1 : 0)
							}
							.frame(minWidth: 46)
							.padding(.vertical, 6)
							.background(RoundedRectangle(cornerRadius: 12).fill(Color.surface2))
							.id(h.time)
							.accessibilityElement(children: .ignore)
							.accessibilityLabel("\(h.time): \(h.temp) graus, \(Weather.label(h.kind))\(h.rain >= 20 ? ", \(h.rain)% de chuva" : "")")
						}
					}
				}
				.noDockMargin()
				.onAppear {
					let now = Calendar.current.dateComponents(in: TripTime.zone, from: Date())
					let today = String(format: "%04d-%02d-%02d", now.year ?? 0, now.month ?? 0, now.day ?? 0)
					let target = day.date == today ? (now.hour ?? 8) : 8
					if let h = hours.first(where: { (Int($0.time.prefix(2)) ?? 0) >= target }) { proxy.scrollTo(h.time, anchor: .leading) }
				}
			}
		}
		.padding(12)
		.background(RoundedRectangle(cornerRadius: 18).fill(Color.surface))
		.overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.line, lineWidth: 2.5))
	}
}

/// The trip's forecast, loaded once per app run (the server caches it for 30 minutes).
@MainActor @Observable
final class WeatherStore {
	static let shared = WeatherStore()
	var days: [String: WeatherDay] = [:]
	private var loadedAt = Date.distantPast

	func load() async {
		guard Date().timeIntervalSince(loadedAt) > 15 * 60 else { return }
		if let w: WeatherData = try? await API.shared.get("/api/weather") {
			days = Dictionary(uniqueKeysWithValues: w.days.map { ($0.date, $0) })
			loadedAt = Date()
		}
	}
}
