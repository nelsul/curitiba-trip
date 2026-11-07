import CoreLocation

/// Asks once for the current position (used for photos without a location, and check-ins).
@MainActor
final class LocationOnce: NSObject, @preconcurrency CLLocationManagerDelegate {
	struct Failure: Error, LocalizedError {
		let message: String
		var errorDescription: String? { message }
	}

	private let manager = CLLocationManager()
	private var continuation: CheckedContinuation<CLLocation, Error>?

	static func current() async throws -> CLLocation {
		try await LocationOnce().run()
	}

	private func run() async throws -> CLLocation {
		manager.delegate = self
		manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
		return try await withCheckedThrowingContinuation { c in
			continuation = c
			switch manager.authorizationStatus {
			case .notDetermined: manager.requestWhenInUseAuthorization()
			case .denied, .restricted: finish(.failure(Failure(message: "Sem permissão de localização. Ative em Ajustes > Viagem.")))
			default: manager.requestLocation()
			}
		}
	}

	private func finish(_ result: Result<CLLocation, Error>) {
		guard let c = continuation else { return }
		continuation = nil
		manager.delegate = nil
		c.resume(with: result)
	}

	func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
		guard continuation != nil else { return }
		switch m.authorizationStatus {
		case .authorizedWhenInUse, .authorizedAlways: m.requestLocation()
		case .denied, .restricted: finish(.failure(Failure(message: "Sem permissão de localização. Ative em Ajustes > Viagem.")))
		default: break
		}
	}

	func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		if let l = locations.last { finish(.success(l)) }
	}

	func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
		finish(.failure(Failure(message: "Não foi possível pegar sua localização agora.")))
	}
}
