import CoreLocation
import Foundation
import SwiftUI

// GET /api/roteiro (web/API.md): the shared places and the days, editable by everyone.

struct RoteiroData: Decodable, Sendable {
	var places: [RoteiroPlace]
	var days: [RoteiroDay]
	/// hotels / Airbnbs (set up by admins on the site); nil from servers before stays existed
	var stays: [RoteiroStay]?
}

/// Where people sleep. `checkIn` = first night, `checkOut` = the day they leave (nil = whole trip).
struct RoteiroStay: Decodable, Hashable, Identifiable, Sendable {
	let id: String
	var name: String
	var kind: String // hotel | airbnb | casa
	var lat: Double
	var lng: Double
	var address: String
	var link: String
	var checkIn: String?
	var checkOut: String?
	var note: String
	var guests: [String]

	var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
	var emoji: String { switch kind { case "airbnb": "🏠"; case "casa": "🏡"; default: "🏨" } }
	var kindLabel: String { switch kind { case "airbnb": "Airbnb"; case "casa": "Casa"; default: "Hotel" } }
	var uberURL: URL { Roteiro.uberURL(lat: lat, lng: lng, name: name) }
	var mapsURL: URL { Roteiro.mapsURL(lat: lat, lng: lng) }
	var linkURL: URL? { link.isEmpty ? nil : URL(string: link) }
}

struct PlacePhoto: Codable, Hashable, Identifiable, Sendable {
	let id: String
	let url: URL
}

struct RoteiroPlace: Codable, Hashable, Identifiable, Sendable {
	let id: String
	var name: String
	var category: String // comer | passeio | outro
	var lat: Double
	var lng: Double
	var address: String
	var hours: String
	var price: String
	var priceLevel: Int?
	var description: String
	var link: String
	var googlePlaceId: String?
	var photos: [PlacePhoto]

	var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
	var categoryInfo: RoteiroCategory { RoteiroCategory(rawValue: category) ?? .passeio }

	/// Opens the Uber app (or m.uber.com) with the place as the destination.
	var uberURL: URL { Roteiro.uberURL(lat: lat, lng: lng, name: name) }

	/// Its Google Maps page (the Google listing when known, otherwise the coordinates).
	var mapsURL: URL {
		var c = URLComponents(string: "https://www.google.com/maps/search/")!
		var items = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: googlePlaceId != nil ? name : "\(lat),\(lng)")]
		if let g = googlePlaceId { items.append(.init(name: "query_place_id", value: g)) }
		c.queryItems = items
		return c.url!
	}

	var linkURL: URL? { link.isEmpty ? nil : URL(string: link) }
}

struct RoteiroStop: Codable, Hashable, Identifiable, Sendable {
	let id: String
	var time: String
	var placeId: String?
	var label: String
	var transport: String
	var note: String
	var visitedAt: String?
	var visitedBy: String?
}

struct RoteiroDay: Codable, Hashable, Identifiable, Sendable {
	var id: String { date }
	let date: String
	var title: String
	var who: String
	var lead: String
	var wedding: Bool
	var stops: [RoteiroStop]
	/// the stay (id) the person asking leaves from that morning / goes back to that night
	var startStay: String?
	var endStay: String?
}

enum RoteiroCategory: String, CaseIterable, Identifiable {
	case comer, passeio, outro
	var id: String { rawValue }
	var label: String { switch self { case .comer: "Comer"; case .passeio: "Passear"; case .outro: "Outro" } }
	var plural: String { switch self { case .comer: "Para comer"; case .passeio: "Para passear"; case .outro: "Outros" } }
	var color: Color { switch self { case .comer: .coral; case .passeio: .leaf; case .outro: .sea } }
}

enum RoteiroTransport: String, CaseIterable, Identifiable {
	case onibus, turismo, uber, pe, rodo
	var id: String { rawValue }
	var label: String {
		switch self {
		case .onibus: "🚌 Ônibus"
		case .turismo: "🚍 Linha Turismo"
		case .uber: "🚗 Uber"
		case .pe: "🚶 A pé"
		case .rodo: "🚌 Ônibus Graciosa"
		}
	}
	var color: Color { switch self { case .onibus, .rodo: .sky; case .turismo: .leaf; case .uber: .plum; case .pe: .coral } }
	static func of(_ raw: String) -> RoteiroTransport { RoteiroTransport(rawValue: raw) ?? .pe }
}

enum Roteiro {
	/// "$$" for price levels 1–4, "Grátis" for 0.
	static func priceSigns(_ level: Int?) -> String {
		guard let level else { return "" }
		return level == 0 ? "Grátis" : String(repeating: "$", count: level)
	}

	/// "9h35" / "14h" → minutes after midnight (nil for free text like "Ida e volta").
	static func minutes(_ time: String) -> Int? {
		guard let m = time.trimmingCharacters(in: .whitespaces).wholeMatch(of: /(\d{1,2})h(\d{2})?/), let h = Int(m.1) else { return nil }
		return h * 60 + (m.2.flatMap { Int($0) } ?? 0)
	}

	/// minutes → "9h35" / "14h" (the format the apps read for reminders)
	static func timeText(_ minutes: Int) -> String {
		let h = minutes / 60, m = minutes % 60
		return m == 0 ? "\(h)h" : String(format: "%dh%02d", h, m)
	}

	static func uberURL(lat: Double, lng: Double, name: String) -> URL {
		var c = URLComponents(string: "https://m.uber.com/ul/")!
		c.queryItems = [
			.init(name: "action", value: "setPickup"), .init(name: "pickup", value: "my_location"),
			.init(name: "dropoff[latitude]", value: String(lat)), .init(name: "dropoff[longitude]", value: String(lng)),
			.init(name: "dropoff[nickname]", value: name)
		]
		return c.url!
	}

	static func mapsURL(lat: Double, lng: Double) -> URL {
		var c = URLComponents(string: "https://www.google.com/maps/search/")!
		c.queryItems = [.init(name: "api", value: "1"), .init(name: "query", value: "\(lat),\(lng)")]
		return c.url!
	}

	/// Google Maps directions through the points, in order.
	static func routeURL(_ places: [CLLocationCoordinate2D]) -> URL? {
		guard places.count >= 2 else { return nil }
		let ll: (CLLocationCoordinate2D) -> String = { "\($0.latitude),\($0.longitude)" }
		var c = URLComponents(string: "https://www.google.com/maps/dir/")!
		var items = [URLQueryItem(name: "api", value: "1"), .init(name: "origin", value: ll(places[0])),
					 .init(name: "destination", value: ll(places.last!)), .init(name: "travelmode", value: "driving")]
		if places.count > 2 { items.append(.init(name: "waypoints", value: places.dropFirst().dropLast().map(ll).joined(separator: "|"))) }
		c.queryItems = items
		return c.url
	}

	/// After the itinerary changes: reschedule the 30-min reminders and the arrival areas on this phone.
	@MainActor static func itineraryChanged() {
		Task {
			await Notifier.shared.scheduleReminders()
			await LocationSharing.shared.updateArrivalRegions()
		}
	}
}

// MARK: - Request bodies

struct PlaceBody: Encodable, Sendable {
	var name: String
	var category: String
	var lat: Double
	var lng: Double
	var address: String
	var hours: String
	var price: String
	var priceLevel: Int?
	var description: String
	var link: String

	// priceLevel must be sent as null to clear it
	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(name, forKey: .name); try c.encode(category, forKey: .category)
		try c.encode(lat, forKey: .lat); try c.encode(lng, forKey: .lng)
		try c.encode(address, forKey: .address); try c.encode(hours, forKey: .hours)
		try c.encode(price, forKey: .price); try c.encode(priceLevel, forKey: .priceLevel)
		try c.encode(description, forKey: .description); try c.encode(link, forKey: .link)
	}
	private enum CodingKeys: String, CodingKey { case name, category, lat, lng, address, hours, price, priceLevel, description, link }
}

struct DayBody: Encodable, Sendable {
	struct Stop: Encodable, Sendable {
		var id: String?
		var time: String
		var placeId: String?
		var label: String
		var transport: String
		var note: String
	}
	var title: String
	var who: String
	var lead: String
	var wedding: Bool
	var stops: [Stop]

	init(_ d: RoteiroDay, stops: [Stop]? = nil) {
		title = d.title; who = d.who; lead = d.lead; wedding = d.wedding
		self.stops = stops ?? d.stops.map { Stop(id: $0.id, time: $0.time, placeId: $0.placeId, label: $0.label, transport: $0.transport, note: $0.note) }
	}
	init(title: String, who: String, lead: String, wedding: Bool, stops: [Stop]) {
		self.title = title; self.who = who; self.lead = lead; self.wedding = wedding; self.stops = stops
	}
}

struct VisitBody: Encodable, Sendable { let visited: Bool }
struct VisitResult: Decodable, Sendable { let visitedAt: String?; let visitedBy: String? }
struct CreatedId: Decodable, Sendable { let id: String }

/// GET /api/roteiro/days/:date/route
struct DayRoute: Decodable, Sendable {
	struct Leg: Decodable, Sendable {
		let transport: String
		let coordinates: [[Double]]
		let routed: Bool
		/// the way back to the stay at the end of the day (drawn dotted)
		var back: Bool?
		/// the number of the stop this leg arrives at (nil for the way back)
		var to: Int?
	}
	let legs: [Leg]
}
