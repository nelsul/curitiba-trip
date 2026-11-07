import Foundation
import Observation

/// Who is signed in. The token lives in the Keychain; `me` is refreshed from /api/me on launch.
@MainActor @Observable
final class AppState {
	enum Phase: Equatable { case loading, signedOut, signedIn(Me), outdated(String) }

	var phase: Phase = .loading
	var people: [Person] = []
	/// Bumped whenever something changes that the feed shows (likes, comments, edits, deletes, uploads).
	var feedVersion = 0

	func feedChanged() { feedVersion += 1 }

	func reloadMe() async {
		if let me: Me = try? await API.shared.get("/api/me") { accept(me, minVersion: me.minAppVersion) }
		await loadPeople()
	}
	var me: Me? { if case .signedIn(let m) = phase { m } else { nil } }

	private let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"

	func restore() async {
		#if DEBUG
		// Simulator testing only: `SIMCTL_CHILD_DEBUG_TOKEN=<token> xcrun simctl launch …` signs in without the email step.
		if let t = ProcessInfo.processInfo.environment["DEBUG_TOKEN"], !t.isEmpty { TokenStore.shared.save(t) }
		#endif
		guard TokenStore.shared.token != nil else { phase = .signedOut; return }
		do {
			let me: Me = try await API.shared.get("/api/me")
			accept(me, minVersion: me.minAppVersion)
			await loadPeople()
		} catch let e as APIError where e.isUnauthorized {
			TokenStore.shared.clear()
			phase = .signedOut
		} catch {
			// offline at launch: stay signed in as the last known person; screens show their own "sem conexão" states
			if let data = UserDefaults.standard.data(forKey: Self.meKey), let cached = try? JSONDecoder().decode(Me.self, from: data) {
				phase = .signedIn(cached)
			} else {
				phase = .signedOut
			}
		}
	}

	func signedIn(_ r: VerifyResponse) async {
		TokenStore.shared.save(r.token)
		accept(r.user, minVersion: r.minAppVersion)
		await loadPeople()
	}

	func signOut() async {
		_ = try? await API.shared.post("/api/auth/logout", Empty()) as OK
		TokenStore.shared.clear()
		UserDefaults.standard.removeObject(forKey: Self.meKey)
		phase = .signedOut
	}

	/// Any 401 from the API means the token is gone (revoked or expired).
	func handle(_ error: Error) {
		if let e = error as? APIError, e.isUnauthorized {
			TokenStore.shared.clear()
			phase = .signedOut
		}
	}

	func person(_ id: String) -> Person? { people.first { $0.id == id } }

	func loadPeople() async {
		if let list: [Person] = try? await API.shared.get("/api/people") { people = list }
	}

	private static let meKey = "me"

	private func accept(_ me: Me, minVersion: String?) {
		if let data = try? JSONEncoder().encode(me) { UserDefaults.standard.set(data, forKey: Self.meKey) }
		if let minVersion, appVersion.compare(minVersion, options: .numeric) == .orderedAscending {
			phase = .outdated(minVersion)
		} else {
			phase = .signedIn(me)
		}
	}
}
