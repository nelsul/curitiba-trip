import Foundation

struct APIError: Error, LocalizedError, Sendable {
	let status: Int
	let message: String
	var errorDescription: String? { message }
	var isUnauthorized: Bool { status == 401 }
}

/// Talks to the web app's JSON API (web/API.md). The server's error messages are already in Portuguese.
struct API: Sendable {
	static let shared = API()

	let base: URL = {
		let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
		return URL(string: raw ?? "") ?? URL(string: "https://viagem.nelsul.com")!
	}()

	private static let decoder = JSONDecoder()
	private static let encoder = JSONEncoder()

	func get<T: Decodable>(_ path: String, query: [String: String?] = [:]) async throws -> T {
		try await send("GET", path, query: query, body: Optional<Empty>.none)
	}

	func post<T: Decodable, B: Encodable>(_ path: String, _ body: B) async throws -> T {
		try await send("POST", path, body: body)
	}

	func patch<T: Decodable, B: Encodable>(_ path: String, _ body: B) async throws -> T {
		try await send("PATCH", path, body: body)
	}

	@discardableResult
	func delete(_ path: String) async throws -> OK {
		try await send("DELETE", path, body: Optional<Empty>.none)
	}

	/// Raw binary body (profile photos, check-in map pictures).
	func put<T: Decodable>(_ path: String, data: Data, contentType: String) async throws -> T {
		var req = request("PUT", path)
		req.setValue(contentType, forHTTPHeaderField: "content-type")
		req.httpBody = data
		return try await perform(req)
	}

	/// Builds a request with auth and app version (also used by the uploader).
	func request(_ method: String, _ path: String, query: [String: String?] = [:]) -> URLRequest {
		var comps = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false)!
		let items = query.compactMap { k, v in v.map { URLQueryItem(name: k, value: $0) } }
		if !items.isEmpty { comps.queryItems = items }
		var req = URLRequest(url: comps.url!)
		req.httpMethod = method
		req.timeoutInterval = 30
		req.setValue("application/json", forHTTPHeaderField: "accept")
		req.setValue(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, forHTTPHeaderField: "x-app-version")
		if let token = TokenStore.shared.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization") }
		return req
	}

	private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
		let data: Data, response: URLResponse
		do {
			(data, response) = try await URLSession.shared.data(for: req)
		} catch {
			throw APIError(status: 0, message: "Sem conexão. Tente de novo em instantes.")
		}
		let status = (response as? HTTPURLResponse)?.statusCode ?? 0
		guard (200..<300).contains(status) else {
			let message = (try? Self.decoder.decode(ServerMessage.self, from: data))?.message ?? "Algo deu errado (\(status))."
			throw APIError(status: status, message: message)
		}
		return try Self.decoder.decode(T.self, from: data)
	}

	private func send<T: Decodable, B: Encodable>(_ method: String, _ path: String, query: [String: String?] = [:], body: B?) async throws -> T {
		var req = request(method, path, query: query)
		if let body {
			req.setValue("application/json", forHTTPHeaderField: "content-type")
			req.httpBody = try Self.encoder.encode(body)
		}
		return try await perform(req)
	}
}

struct Empty: Codable, Sendable {}
struct OK: Decodable, Sendable { var ok: Bool? }
private struct ServerMessage: Decodable { let message: String }
