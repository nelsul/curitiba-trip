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
