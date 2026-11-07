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
	var likers: [String]
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

struct FeedPage: Decodable, Sendable { let posts: [Post]; let nextCursor: String? }
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
