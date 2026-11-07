import CoreLocation
import Observation
import os

/// "Compartilhar local" (web location.svelte.ts): while on, the phone's position goes to the group map.
/// Same throttle as the web: skip points within 30 m and 3 min of the last one sent, and very imprecise ones.
@MainActor @Observable
final class LocationSharing: NSObject {
	static let shared = LocationSharing()
	private static let pref = "compartilhar-localizacao"

	private(set) var sharing = false
	private(set) var last: CLLocation?
	var error: String?

	@ObservationIgnored private let manager = CLLocationManager()
	@ObservationIgnored private var lastSent: CLLocation?
	private let log = Logger(subsystem: "com.nelsul.curitibatrip", category: "location")

	private override init() {
		super.init()
		manager.delegate = self
		manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
		manager.distanceFilter = 20
		manager.activityType = .otherNavigation
	}

	/// Turns sharing back on if it was on last time.
	func restore() {
		if UserDefaults.standard.bool(forKey: Self.pref) { start() }
	}

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
		guard sharing else { return }
		manager.startUpdatingLocation()
		if let last { Task { await send(last, force: true) } }
	}

	private func denied() {
		error = "Sem permissão de localização. Ative em Ajustes > Viagem > Localização."
		stop()
	}

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
		guard sharing else { return }
		switch m.authorizationStatus {
		case .authorizedWhenInUse, .authorizedAlways: m.startUpdatingLocation()
		case .denied, .restricted: denied()
		default: break
		}
	}

	func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let l = locations.last else { return }
		last = l
		error = nil
		if sharing { Task { await send(l) } }
	}

	func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
		if (error as? CLError)?.code == .denied { denied() }
	}
}

struct PositionBody: Encodable, Sendable {
	let lat: Double
	let lng: Double
	let accuracy: Double
}
