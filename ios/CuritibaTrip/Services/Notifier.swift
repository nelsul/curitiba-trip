import BackgroundTasks
import Foundation
import Observation
import UserNotifications
import os

/// Local notifications (no push server):
/// - **Novidades:** a background check of GET /api/activity ("Bruna postou 3 fotos", comments and likes on my posts).
/// - **Roteiro:** a reminder 30 min before each stop with a time.
/// - **Chegada:** "Chegou no Jardim Botânico? Fazer check-in" when entering a stop's area (see LocationSharing).
/// Each kind has its own switch in Mais. Tapping one opens the post, or the map's check-in.
@MainActor @Observable
final class Notifier: NSObject {
	static let shared = Notifier()
	static let refreshTask = "com.nelsul.curitibatrip.activity"

	enum Kind: String, CaseIterable { case activity = "avisos-novidades", itinerary = "avisos-roteiro", arrival = "avisos-chegada" }

	/// Where a tapped notification wants to go (the shell picks these up).
	var openRoute: Route?
	var openCheckin = false
	private(set) var authorized = false

	private let center = UNUserNotificationCenter.current()
	private let log = Logger(subsystem: "com.nelsul.curitibatrip", category: "notify")
	private static let sinceKey = "atividade-desde"

	private override init() {
		super.init()
		UserDefaults.standard.register(defaults: [Kind.activity.rawValue: true, Kind.itinerary.rawValue: true, Kind.arrival.rawValue: false])
	}

	func isOn(_ k: Kind) -> Bool { UserDefaults.standard.bool(forKey: k.rawValue) }

	func set(_ k: Kind, _ on: Bool) async {
		UserDefaults.standard.set(on, forKey: k.rawValue)
		if on { await requestPermission() }
		switch k {
		case .activity: if on { scheduleRefresh() }
		case .itinerary: await scheduleReminders()
		case .arrival: await LocationSharing.shared.updateArrivalRegions()
		}
	}

	/// Asks once (after sign-in); afterwards just reads the current answer.
	func requestPermission() async {
		let settings = await center.notificationSettings()
		if settings.authorizationStatus == .notDetermined {
			authorized = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
		} else {
			authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
		}
	}

	/// Called on launch: delegate for taps, background check, reminders.
	func start() async {
		center.delegate = self
		await requestPermission()
		scheduleRefresh()
		await scheduleReminders()
	}

	// MARK: - Novidades (background check)

	static func registerBackgroundTask() {
		BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTask, using: nil) { task in
			let work = Task { @MainActor in
				Notifier.shared.scheduleRefresh() // the next one
				await Notifier.shared.checkActivity()
				task.setTaskCompleted(success: true)
			}
			task.expirationHandler = { work.cancel() }
		}
	}

	func scheduleRefresh() {
		guard isOn(.activity) else { return }
		let req = BGAppRefreshTaskRequest(identifier: Self.refreshTask)
		req.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
		do { try BGTaskScheduler.shared.submit(req) } catch { log.debug("refresh not scheduled: \(error.localizedDescription, privacy: .public)") }
	}

	/// Things seen in the app don't need a notification: start counting from now.
	func markSeen() {
		UserDefaults.standard.set(Date().formatted(.iso8601), forKey: Self.sinceKey)
	}

	private var lastCheck = Date.distantPast

	/// Asks the server what other people did since the last check and shows it as notifications.
	func checkActivity() async {
		guard isOn(.activity), TokenStore.shared.token != nil, Date().timeIntervalSince(lastCheck) > 60 else { return }
		lastCheck = Date()
		guard let since = UserDefaults.standard.string(forKey: Self.sinceKey) else { return markSeen() }
		do {
			let a: Activity = try await API.shared.get("/api/activity", query: ["since": since])
			let people: [Person] = (try? await API.shared.get("/api/people")) ?? []
			let name = { (id: String) in people.first { $0.id == id }?.name ?? "Alguém" }
			for p in a.posts {
				let what = [p.photos > 0 ? "\(p.photos) \(p.photos == 1 ? "foto" : "fotos")" : nil,
							p.videos > 0 ? "\(p.videos) \(p.videos == 1 ? "vídeo" : "vídeos")" : nil].compactMap { $0 }.joined(separator: " e ")
				await post(id: "post-\(p.firstId)", title: "\(name(p.userId)) postou \(what)", body: "Veja no diário da viagem.", route: .media(p.firstId))
			}
			for c in a.checkins {
				await post(id: "checkin-\(c.id)", title: "\(name(c.userId)) fez check-in", body: c.note.isEmpty ? "Veja onde no mapa." : c.note, route: .checkin(c.id))
			}
			for c in a.comments {
				let route: Route? = c.mediaId.map(Route.media) ?? c.checkinId.map(Route.checkin)
				await post(id: "comment-\(c.id)", title: "\(name(c.userId)) comentou no seu post", body: c.body, route: route)
			}
			// likes: one line per person
			for (userId, rows) in Dictionary(grouping: a.likes, by: \.userId) {
				let first = rows[0]
				let route: Route? = first.mediaId.map(Route.media) ?? first.checkinId.map(Route.checkin)
				let n = rows.count
				await post(id: "likes-\(userId)-\(a.now)", title: "\(name(userId)) curtiu \(n == 1 ? "seu post" : "\(n) posts seus") ❤️", body: "", route: route)
			}
			UserDefaults.standard.set(a.now, forKey: Self.sinceKey)
		} catch {
			log.error("activity check failed: \(error.localizedDescription, privacy: .public)")
		}
	}

	private func post(id: String, title: String, body: String, route: Route?, checkin: Bool = false, at date: Date? = nil) async {
		let content = UNMutableNotificationContent()
		content.title = title
		content.body = body
		content.sound = .default
		var info: [String: String] = [:]
		switch route {
		case .media(let x): info["media"] = x
		case .checkin(let x): info["checkin"] = x
		case nil: break
		}
		if checkin { info["action"] = "checkin" }
		content.userInfo = info
		let trigger = date.map { UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0), repeats: false) }
		try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
	}

	// MARK: - Roteiro (reminders 30 min before each stop)

	private static let reminderPrefix = "roteiro-"

	func scheduleReminders() async {
		let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.reminderPrefix) }
		center.removePendingNotificationRequests(withIdentifiers: pending)
		guard isOn(.itinerary), TokenStore.shared.token != nil, let it: Itinerary = try? await API.shared.get("/api/itinerary") else { return }
		for stop in Self.timedStops(it) where stop.date.timeIntervalSinceNow > 31 * 60 {
			let s = stop.stop
			let transport = it.transport[s.transport]?.label
			let body = [s.place?.name == s.title ? nil : s.place?.name, transport, s.note.isEmpty ? nil : s.note].compactMap { $0 }.joined(separator: " · ")
			await post(id: "\(Self.reminderPrefix)\(stop.day)-\(s.time)", title: "Daqui a 30 min: \(s.title)", body: body, route: nil,
					   at: stop.date.addingTimeInterval(-30 * 60))
		}
	}

	struct TimedStop { let day: String; let date: Date; let stop: Itinerary.Stop }

	/// Stops whose time reads like "9h35" or "14h", as dates in Curitiba time.
	static func timedStops(_ it: Itinerary) -> [TimedStop] {
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TripTime.zone
		return it.days.flatMap { day in
			day.stops.compactMap { s -> TimedStop? in
				guard let m = s.time.wholeMatch(of: /(\d{1,2})h(\d{2})?/), let h = Int(m.1) else { return nil }
				let parts = day.date.split(separator: "-").compactMap { Int($0) }
				guard parts.count == 3, let date = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: h, minute: m.2.flatMap { Int($0) } ?? 0))
				else { return nil }
				return TimedStop(day: day.date, date: date, stop: s)
			}
		}
	}

	// MARK: - Chegada

	func arrived(at place: String, regionId: String) async {
		guard isOn(.arrival) else { return }
		// once per place per day
		let key = "chegou-\(regionId)-\(TripTime.dayKey(Date().formatted(.iso8601)))"
		guard !UserDefaults.standard.bool(forKey: key) else { return }
		UserDefaults.standard.set(true, forKey: key)
		await post(id: key, title: "Chegou em \(place)? 📍", body: "Toque para fazer check-in e aparecer no mapa e no diário.", route: nil, checkin: true)
	}
}

extension Notifier: @preconcurrency UNUserNotificationCenterDelegate {
	func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification) async -> UNNotificationPresentationOptions {
		[.banner, .sound, .list]
	}

	func userNotificationCenter(_ c: UNUserNotificationCenter, didReceive r: UNNotificationResponse) async {
		let info = r.notification.request.content.userInfo
		if info["action"] as? String == "checkin" { openCheckin = true }
		else if let id = info["media"] as? String { openRoute = .media(id) }
		else if let id = info["checkin"] as? String { openRoute = .checkin(id) }
	}
}

/// GET /api/activity
struct Activity: Decodable, Sendable {
	struct Posts: Decodable, Sendable { let userId: String; let photos: Int; let videos: Int; let firstId: String }
	struct Checkin: Decodable, Sendable { let id: String; let userId: String; let note: String }
	struct Comment: Decodable, Sendable { let id: String; let userId: String; let body: String; let mediaId: String?; let checkinId: String? }
	struct Like: Decodable, Sendable { let userId: String; let mediaId: String?; let checkinId: String? }
	let now: String
	let posts: [Posts]
	let checkins: [Checkin]
	let comments: [Comment]
	let likes: [Like]
}
