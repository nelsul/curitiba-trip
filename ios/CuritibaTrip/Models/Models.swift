import Foundation
import SwiftUI

// Types mirror web/API.md. Dates arrive as ISO-8601 strings.

struct Person: Codable, Identifiable, Hashable, Sendable {
	let id: String
	let name: String
	let color: String
	let photo: URL?
	var tint: Color { Color(hex: color) }
}

struct Me: Codable, Hashable, Sendable {
	let id: String
	let name: String
	let color: String
	let photo: URL?
	let isAdmin: Bool
	var minAppVersion: String?
	var tint: Color { Color(hex: color) }
}

struct CodeResponse: Decodable, Sendable { let maskedEmail: String }
struct VerifyResponse: Decodable, Sendable { let token: String; let user: Me; let minAppVersion: String }

struct FeedMedia: Codable, Identifiable, Hashable, Sendable {
	let id: String
	let userId: String
	let at: String
	let day: String
	let kind: String // "photo" | "video"
	let status: String // "processing" | "ready" | "failed"
	let thumb: URL?
	let image: URL?
	let video: URL?
	let width: Int?
	let height: Int?
	var likers: [String]
	let lat: Double?
	let lng: Double?
	let caption: String
	let comments: Int
	/// the first (oldest) two comments, shown under the post
	var firstComments: [PreviewComment]? = nil
	let durationS: Double?
	var isVideo: Bool { kind == "video" }
}

struct FeedCheckin: Codable, Identifiable, Hashable, Sendable {
	let id: String
	let userId: String
	let at: String
	let day: String
	let lat: Double
	let lng: Double
	let note: String
	let snapshot: URL?
	let comments: Int
	var firstComments: [PreviewComment]? = nil
	var likers: [String]
}

struct PreviewComment: Codable, Hashable, Sendable {
	let id: String
	let userId: String
	let body: String
}

/// A feed post: a carousel of photos/videos, or a check-in (grouped by the server like the web).
enum Post: Decodable, Identifiable, Hashable, Sendable {
	case media(key: String, userId: String, day: String, at: String, items: [FeedMedia])
	case checkin(key: String, userId: String, day: String, at: String, item: FeedCheckin)

	var id: String { key }
	var key: String { switch self { case .media(let k, _, _, _, _), .checkin(let k, _, _, _, _): k } }
	var userId: String { switch self { case .media(_, let u, _, _, _), .checkin(_, let u, _, _, _): u } }
	var day: String { switch self { case .media(_, _, let d, _, _), .checkin(_, _, let d, _, _): d } }

	private enum CodingKeys: String, CodingKey { case type, key, userId, day, at, items, item }
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		let key = try c.decode(String.self, forKey: .key), user = try c.decode(String.self, forKey: .userId)
		let day = try c.decode(String.self, forKey: .day), at = try c.decode(String.self, forKey: .at)
		if try c.decode(String.self, forKey: .type) == "checkin" {
			self = .checkin(key: key, userId: user, day: day, at: at, item: try c.decode(FeedCheckin.self, forKey: .item))
		} else {
			self = .media(key: key, userId: user, day: day, at: at, items: try c.decode([FeedMedia].self, forKey: .items))
		}
	}
}

struct FeedPage: Decodable, Sendable { let posts: [Post]; let nextCursor: String?; var days: [String]? }
struct LikeBody: Encodable, Sendable { var mediaId: String?; var checkinId: String?; let liked: Bool }
struct LikeResponse: Decodable, Sendable { let likers: [String] }

// MARK: - Details and comments

struct Comment: Codable, Identifiable, Hashable, Sendable {
	let id: String
	let body: String
	let at: String
	let userId: String
	let name: String
	let color: String
	let photo: URL?
	var tint: Color { Color(hex: color) }
}

struct MediaItem: Codable, Hashable, Sendable {
	let id: String
	let userId: String
	let kind: String
	let status: String
	let at: String
	let takenAtSource: String?
	let lat: Double?
	let lng: Double?
	let locationSource: String?
	let width: Int?
	let height: Int?
	let durationS: Double?
	let sizeBytes: Int
	let originalName: String
	let caption: String
	let display: URL?
	let medium: URL?
	let video: URL?
	let poster: URL?
	let original: URL?
	var isVideo: Bool { kind == "video" }
}

struct MediaDetail: Decodable, Sendable { var item: MediaItem; var comments: [Comment]; var likers: [String] }

struct CheckinItem: Codable, Hashable, Sendable {
	let id: String
	let userId: String
	let snapshot: URL?
	let lat: Double
	let lng: Double
	let note: String
	let at: String
}

struct CheckinDetail: Decodable, Sendable { var item: CheckinItem; var comments: [Comment]; var likers: [String] }

// MARK: - Itinerary

struct Itinerary: Decodable, Sendable {
	struct Transport: Decodable, Sendable { let label: String }
	struct Place: Decodable, Sendable { let id: String; let name: String; let lat: Double; let lng: Double; let hours: String; let mapsUrl: URL; let uberUrl: URL }
	struct Stop: Decodable, Sendable, Identifiable { var id: String { time + title }; let time: String; let transport: String; let note: String; let title: String; let place: Place? }
	struct Day: Decodable, Sendable, Identifiable { var id: String { date }; let date: String; let title: String; let who: String; let lead: String; let wedding: Bool; let routeUrl: URL?; let stops: [Stop] }
	let transport: [String: Transport]
	let days: [Day]
}

// MARK: - Devices

struct Device: Decodable, Identifiable, Sendable { let id: String; let deviceName: String?; let lastUsedAt: String?; let createdAt: String; let current: Bool }

// MARK: - Map (GET /api/map)

/// A located post or check-in on the map.
enum MapItem: Decodable, Identifiable, Hashable, Sendable {
	case media(FeedMedia)
	case checkin(FeedCheckin)

	private enum Key: String, CodingKey { case type }

	init(from decoder: Decoder) throws {
		let type = try decoder.container(keyedBy: Key.self).decode(String.self, forKey: .type)
		self = type == "checkin" ? .checkin(try FeedCheckin(from: decoder)) : .media(try FeedMedia(from: decoder))
	}

	var id: String { switch self { case .media(let m): m.id; case .checkin(let c): c.id } }
	var userId: String { switch self { case .media(let m): m.userId; case .checkin(let c): c.userId } }
	var day: String { switch self { case .media(let m): m.day; case .checkin(let c): c.day } }
	var at: String { switch self { case .media(let m): m.at; case .checkin(let c): c.at } }
	var lat: Double { switch self { case .media(let m): m.lat ?? 0; case .checkin(let c): c.lat } }
	var lng: Double { switch self { case .media(let m): m.lng ?? 0; case .checkin(let c): c.lng } }
}

struct MapPing: Decodable, Hashable, Sendable {
	let userId: String
	let lat: Double
	let lng: Double
	let at: String
	let day: String
}

/// Someone's latest shared position.
struct LatestLocation: Decodable, Hashable, Identifiable, Sendable {
	let userId: String
	let name: String
	let color: String
	let photo: URL?
	let lat: Double
	let lng: Double
	let at: String
	var id: String { userId }
	var tint: Color { Color(hex: color) }
}

struct MapData: Decodable, Sendable {
	let items: [MapItem]
	let pings: [MapPing]
	let latest: [LatestLocation]
}

struct CheckinCreated: Decodable, Sendable { let id: String }

// MARK: - Cotinha (GET /api/splits)

struct SplitShare: Codable, Hashable, Sendable { let userId: String; let amountCents: Int; let paidAt: String? }

struct Split: Codable, Identifiable, Hashable, Sendable {
	let id: String
	let title: String
	let totalCents: Int
	let payerId: String
	let pixKey: String
	let note: String
	let createdAt: String
	let remindedAt: String?
	let shares: [SplitShare]
	var open: Bool { shares.contains { $0.paidAt == nil } }
}

struct SplitList: Decodable, Sendable { let splits: [Split]; let myPix: String }
struct NewSplit: Encodable, Sendable { let title: String; let totalCents: Int; let pixKey: String; let note: String; let participants: [String] }
struct PaidBody: Encodable, Sendable { let userId: String; let paid: Bool }

enum Money {
	/// 12345 → "R$ 123,45"
	static func brl(_ cents: Int) -> String {
		let f = NumberFormatter()
		f.numberStyle = .currency
		f.locale = Locale(identifier: "pt_BR")
		return f.string(from: NSNumber(value: Double(cents) / 100)) ?? "R$ \(cents / 100)"
	}

	/// "123,45" / "1.234,5" → cents
	static func cents(_ text: String) -> Int? {
		var t = text.filter { "0123456789,.".contains($0) }
		guard !t.isEmpty else { return nil }
		if t.contains(",") { t = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") }
		else if t.filter({ $0 == "." }).count > 1 || t.range(of: #"\.\d{3}$"#, options: .regularExpression) != nil { t = t.replacingOccurrences(of: ".", with: "") }
		guard let v = Double(t) else { return nil }
		return Int((v * 100).rounded())
	}

	/// Equal parts that always add up (the leftover cents go to the first people).
	static func parts(_ total: Int, _ n: Int) -> [Int] {
		guard n > 0 else { return [] }
		let base = total / n
		return (0..<n).map { base + ($0 < total - base * n ? 1 : 0) }
	}
}

// MARK: - Retrospectiva, the couple's likes, weather

struct Retro: Decodable, Sendable { let weddingAt: String; let items: [FeedMedia] }
struct RetroBody: Encodable, Sendable { let mediaIds: [String] }

struct CoupleLike: Decodable, Identifiable, Sendable {
	let id: Int
	let likerId: String
	let role: String // noivo | noiva
	let mediaId: String?
	let checkinId: String?
	let image: URL?
}
struct CoupleLikes: Decodable, Sendable { let likes: [CoupleLike] }
struct SeenBody: Encodable, Sendable { let upTo: Int }

struct WeatherHour: Decodable, Hashable, Sendable { let time: String; let temp: Int; let rain: Int; let kind: String }
struct WeatherDay: Decodable, Hashable, Sendable {
	let date: String
	let min: Int
	let max: Int
	let rain: Int
	let kind: String
	let hours: [WeatherHour]
}
struct WeatherData: Decodable, Sendable { let days: [WeatherDay] }

enum Weather {
	static func icon(_ kind: String) -> IconName {
		switch kind { case "sun": .sun; case "partly": .partly; case "cloud": .cloud; case "fog": .fog; case "storm": .storm; default: .rain }
	}
	static func label(_ kind: String) -> String {
		switch kind { case "sun": "Sol"; case "partly": "Sol entre nuvens"; case "cloud": "Nublado"; case "fog": "Neblina"; case "storm": "Tempestade"; default: "Chuva" }
	}
	static func color(_ t: Int) -> Color { t >= 26 ? .coral : t >= 20 ? .sun : t >= 14 ? .leaf : .sky }
}

/// The trip's wedding start (countdown target), same as web src/lib/trip.ts.
enum Wedding {
	static let at = TripTime.date("2026-11-14T16:00:00.000-03:00") ?? Date(timeIntervalSince1970: 1_794_682_800)
}
