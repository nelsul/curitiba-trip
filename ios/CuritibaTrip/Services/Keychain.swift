import Foundation
import OSLog
import Security

/// The device login token: kept in memory for this run and persisted in the iOS Keychain
/// (never in UserDefaults or files). If the Keychain write fails, the session still works until the app quits.
final class TokenStore: @unchecked Sendable {
	static let shared = TokenStore()
	private let lock = NSLock()
	private var cached: String?
	private var loaded = false
	private let log = Logger(subsystem: "com.nelsul.curitibatrip", category: "auth")

	private let service = "com.nelsul.curitibatrip"
	private let account = "session-token"

	var token: String? {
		lock.lock(); defer { lock.unlock() }
		if !loaded { cached = readKeychain(); loaded = true }
		return cached
	}

	func save(_ token: String) {
		lock.lock(); defer { lock.unlock() }
		cached = token
		loaded = true
		deleteKeychain()
		let item: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
			kSecValueData as String: Data(token.utf8),
			kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
		]
		let status = SecItemAdd(item as CFDictionary, nil)
		if status != errSecSuccess { log.error("Keychain save failed: \(status)") }
	}

	func clear() {
		lock.lock(); defer { lock.unlock() }
		cached = nil
		loaded = true
		deleteKeychain()
	}

	private func readKeychain() -> String? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]
		var out: AnyObject?
		let status = SecItemCopyMatching(query as CFDictionary, &out)
		if status != errSecSuccess && status != errSecItemNotFound { log.error("Keychain read failed: \(status)") }
		guard status == errSecSuccess, let data = out as? Data else { return nil }
		return String(data: data, encoding: .utf8)
	}

	private func deleteKeychain() {
		let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
		SecItemDelete(query as CFDictionary)
	}
}
