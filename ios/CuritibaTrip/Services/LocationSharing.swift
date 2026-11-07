import CoreLocation
import Observation
import UIKit
import os

/// Where I am, for the group map.
/// - **Compartilhar local** (on the map): live updates while the app is open. Same throttle as the web: skip points
///   within 30 m and 3 min of the last one sent, and very imprecise ones.
/// - **Com o app fechado** (switch in Mais, off by default): battery-friendly significant changes and visits,
///   queued with their real times and sent to /api/locations/batch, so each day's trail draws itself.
/// - **Chegada** areas around the next itinerary stops (needs "Sempre").
@MainActor @Observable
final class LocationSharing: NSObject {
	static let shared = LocationSharing()
	private static let pref = "compartilhar-localizacao"
	private static let backgroundPref = "localizacao-segundo-plano"
	private static let queueKey = "localizacao-fila"

	private(set) var sharing = false
	private(set) var background = false
	private(set) var last: CLLocation?
	var error: String?

	@ObservationIgnored private let manager = CLLocationManager()
	@ObservationIgnored private var lastSent: CLLocation?
	@ObservationIgnored private var started = false
	/// The itinerary areas being watched (`monitoredRegions` lags behind changes, so we keep our own copy).
	@ObservationIgnored private var arrivalAreas: [CLCircularRegion] = []
	private let log = Logger(subsystem: "com.nelsul.curitibatrip", category: "location")

	private override init() {
		super.init()
		manager.delegate = self
		manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
		manager.distanceFilter = 20
		manager.activityType = .otherNavigation
		manager.pausesLocationUpdatesAutomatically = true
	}

	var hasAlways: Bool { manager.authorizationStatus == .authorizedAlways }

	/// On launch (also when iOS relaunches the app in the background for a location event).
	func restore() {
		guard !started else { return }
		started = true
		arrivalAreas = manager.monitoredRegions.compactMap { $0 as? CLCircularRegion }
		if UserDefaults.standard.bool(forKey: Self.pref) { start() }
		if UserDefaults.standard.bool(forKey: Self.backgroundPref) { startBackground() }
		Task { await flush() }
	}

	// MARK: Live (app open)

	func start() {
		error = nil
		sharing = true
		UserDefaults.standard.set(true, forKey: Self.pref)
		switch manager.authorizationStatus {
		case .notDetermined: manager.requestWhenInUseAuthorization()
		case .denied, .restricted: denied()
		default: manager.startUpdatingLocation()
		}
	}

	func stop() {
		sharing = false
		UserDefaults.standard.set(false, forKey: Self.pref)
		manager.stopUpdatingLocation()
	}

	/// Back in the app: send the current spot right away so the others see you're here.
	func resume() {
		Task { await flush() }
		guard sharing else { return }
		manager.startUpdatingLocation()
		if let last { Task { await send(last, force: true) } }
	}

	/// Leaving the app: live updates stop (background mode keeps the light ones).
	func pause() {
		if sharing { manager.stopUpdatingLocation() }
	}

	private func denied() {
		error = "Sem permissão de localização. Ative em Ajustes > Viagem > Localização."
		stop()
	}

	// MARK: App closed

	/// Turns on light background tracking. iOS asks for "Sempre" (after "Durante o uso").
	func setBackground(_ on: Bool) {
		background = on
		UserDefaults.standard.set(on, forKey: Self.backgroundPref)
		if on { startBackground() } else { stopBackground() }
	}

	private func startBackground() {
		background = true
		switch manager.authorizationStatus {
		case .notDetermined: manager.requestWhenInUseAuthorization() // then "Sempre" (didChangeAuthorization)
		case .authorizedWhenInUse: manager.requestAlwaysAuthorization()
		case .authorizedAlways:
			manager.startMonitoringSignificantLocationChanges()
			manager.startMonitoringVisits()
			Task { await updateArrivalRegions() }
		default:
			error = "Para o caminho com o app fechado, permita a localização \"Sempre\" em Ajustes > Viagem."
		}
	}

	private func stopBackground() {
		manager.stopMonitoringSignificantLocationChanges()
		manager.stopMonitoringVisits()
		for r in manager.monitoredRegions { manager.stopMonitoring(for: r) }
		arrivalAreas = []
	}

	private struct Queued: Codable { let lat: Double; let lng: Double; let accuracy: Double; let at: String }

	private func enqueue(_ l: CLLocation) {
		guard l.horizontalAccuracy >= 0, l.horizontalAccuracy <= 500 else { return }
		var q = (UserDefaults.standard.data(forKey: Self.queueKey)).flatMap { try? JSONDecoder().decode([Queued].self, from: $0) } ?? []
		q.append(Queued(lat: l.coordinate.latitude, lng: l.coordinate.longitude, accuracy: l.horizontalAccuracy, at: l.timestamp.formatted(.iso8601)))
		if q.count > 500 { q.removeFirst(q.count - 500) }
		UserDefaults.standard.set(try? JSONEncoder().encode(q), forKey: Self.queueKey)
	}

	/// Sends the queued points (the server drops ones older than 48 h).
	private func flush() async {
		guard TokenStore.shared.token != nil,
			  let data = UserDefaults.standard.data(forKey: Self.queueKey),
			  let q = try? JSONDecoder().decode([Queued].self, from: data), !q.isEmpty else { return }
		// a little time to finish if iOS woke the app just for this point
		let bg = UIApplication.shared.beginBackgroundTask(withName: "localizacao")
		defer { UIApplication.shared.endBackgroundTask(bg) }
		do {
			let _: BatchResult = try await API.shared.post("/api/locations/batch", q)
			UserDefaults.standard.removeObject(forKey: Self.queueKey)
		} catch {
			log.error("batch failed, will retry: \(error.localizedDescription, privacy: .public)")
		}
	}

	// MARK: Chegada (itinerary areas)

	/// Watches the next stops of the itinerary (iOS allows 20 areas; we use up to 15).
	/// Watches the next stops of the itinerary (iOS allows 20 areas; we use up to 15). Several callers can ask at
	/// once during launch, so it computes the new list first and then only changes what differs.
	func updateArrivalRegions() async {
		var wanted: [CLCircularRegion] = []
		if background, hasAlways, Notifier.shared.isOn(.arrival) {
			// offline: keep the current areas
			guard let it: Itinerary = try? await API.shared.get("/api/itinerary") else { return }
			let upcoming = Notifier.timedStops(it).filter { $0.date.timeIntervalSinceNow > -3 * 3600 && $0.stop.place != nil }
			var seen = Set<String>()
			for s in upcoming {
				guard let p = s.stop.place, seen.insert(p.id).inserted else { continue }
				let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: p.lat, longitude: p.lng), radius: 150, identifier: "\(p.id)|\(p.name)")
				region.notifyOnEntry = true
				region.notifyOnExit = false
				wanted.append(region)
				if wanted.count >= 15 { break }
			}
		}
		let ids = Set(wanted.map(\.identifier))
		for r in manager.monitoredRegions where !ids.contains(r.identifier) { manager.stopMonitoring(for: r) }
		let had = Set(arrivalAreas.map(\.identifier))
		for r in wanted where !had.contains(r.identifier) {
			manager.startMonitoring(for: r)
			manager.requestState(for: r) // already there? (answered in didDetermineState)
		}
		arrivalAreas = wanted
	}

	/// Region entry events can be slow or missed, so every precise position is also checked against the areas.
	private func checkArrival(_ l: CLLocation) {
		guard background, l.horizontalAccuracy >= 0, l.horizontalAccuracy <= 100 else { return }
		for r in arrivalAreas where r.contains(l.coordinate) { arrived(in: r) }
	}

	private func arrived(in region: CLRegion) {
		let parts = region.identifier.split(separator: "|", maxSplits: 1)
		guard parts.count == 2 else { return }
		Task { await Notifier.shared.arrived(at: String(parts[1]), regionId: String(parts[0])) }
	}

	// MARK: Sending

	private func send(_ l: CLLocation, force: Bool = false) async {
		guard l.horizontalAccuracy >= 0, l.horizontalAccuracy <= 500 else { return }
		if !force, let prev = lastSent, prev.distance(from: l) < 30, l.timestamp.timeIntervalSince(prev.timestamp) < 180 { return }
		lastSent = l
		do {
			let _: OK = try await API.shared.post("/api/locations", PositionBody(lat: l.coordinate.latitude, lng: l.coordinate.longitude, accuracy: l.horizontalAccuracy))
		} catch {
			lastSent = nil // try again with the next update
			log.error("could not send position: \(error.localizedDescription, privacy: .public)")
		}
	}
}

extension LocationSharing: @preconcurrency CLLocationManagerDelegate {
	func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
		switch m.authorizationStatus {
		case .authorizedWhenInUse:
			if sharing { m.startUpdatingLocation() }
			if background { m.requestAlwaysAuthorization() }
		case .authorizedAlways:
			if sharing { m.startUpdatingLocation() }
			if background { startBackground() }
		case .denied, .restricted:
			if sharing { denied() }
		default: break
		}
	}

	func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let l = locations.last else { return }
		last = l
		error = nil
		checkArrival(l)
		if UIApplication.shared.applicationState == .background {
			// woken by a significant change: queue it with its real time and send what we have
			guard background else { return }
			locations.forEach(enqueue)
			Task {
				await flush()
				await Notifier.shared.checkActivity()
			}
		} else if sharing {
			Task { await send(l) }
		}
	}

	func locationManager(_ m: CLLocationManager, didVisit visit: CLVisit) {
		guard background, visit.horizontalAccuracy <= 500 else { return }
		let at = visit.arrivalDate == .distantPast ? visit.departureDate : visit.arrivalDate
		enqueue(CLLocation(coordinate: visit.coordinate, altitude: 0, horizontalAccuracy: visit.horizontalAccuracy, verticalAccuracy: -1, timestamp: at))
		Task { await flush() }
	}

	func locationManager(_ m: CLLocationManager, didEnterRegion region: CLRegion) { arrived(in: region) }

	func locationManager(_ m: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
		if state == .inside { arrived(in: region) }
	}

	func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
		if (error as? CLError)?.code == .denied, sharing { denied() }
	}
}

struct PositionBody: Encodable, Sendable {
	let lat: Double
	let lng: Double
	let accuracy: Double
}

private struct BatchResult: Decodable { let received: Int; let stored: Int }
