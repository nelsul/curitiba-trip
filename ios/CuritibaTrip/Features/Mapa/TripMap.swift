import MapLibre
import SwiftUI

/// The island night style (GET /api/map-style.json). It's fetched with the app's token and kept as a local
/// file, because MapLibre would otherwise send the token to the tile servers too.
enum MapStyle {
	private static let file = URL.cachesDirectory.appending(path: "map-style.json")
	private static let maxAge: TimeInterval = 3600

	static func url() async throws -> URL {
		let fm = FileManager.default
		if let date = (try? fm.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date, Date().timeIntervalSince(date) < maxAge {
			return file
		}
		do {
			let (data, response) = try await URLSession.shared.data(for: API.shared.request("GET", "/api/map-style.json"))
			guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError(status: 0, message: "Mapa indisponível.") }
			try data.write(to: file, options: .atomic)
		} catch {
			if !fm.fileExists(atPath: file.path) { throw APIError(status: 0, message: "Sem conexão para carregar o mapa.") }
			// offline: the older copy still works
		}
		return file
	}
}

/// One person's path on one day.
struct Trail: Hashable {
	let userId: String
	let color: String
	let coordinates: [CLLocationCoordinate2D]

	static func == (a: Trail, b: Trail) -> Bool { a.userId == b.userId && a.coordinates.count == b.coordinates.count }
	func hash(into h: inout Hasher) { h.combine(userId); h.combine(coordinates.count) }
}

/// MapLibre map with the trip's markers (polaroids, check-in pins, people) and dotted trails.
struct TripMap: UIViewRepresentable {
	let styleURL: URL
	var items: [MapItem] = []
	var trails: [Trail] = []
	var people: [LatestLocation] = []
	var colors: [String: Color] = [:]
	/// Change this to make the map fit everything shown (filters changed, first load).
	var fitToken = 0
	/// Set to fly somewhere (a new check-in, a focused photo).
	var flyTo: CLLocationCoordinate2D?
	var initialCenter: CLLocationCoordinate2D?
	var initialZoom: Double = 12
	var onOpen: (Route) -> Void = { _ in }
	/// Called as the map moves (location picker).
	var onCenter: ((CLLocationCoordinate2D) -> Void)?

	func makeCoordinator() -> Coordinator { Coordinator() }

	func makeUIView(context: Context) -> MLNMapView {
		let map = MLNMapView(frame: .zero, styleURL: styleURL)
		map.delegate = context.coordinator
		map.logoView.isHidden = true
		map.attributionButtonPosition = .bottomRight
		map.compassViewPosition = .topRight
		map.backgroundColor = UIColor(Color.bg)
		map.setCenter(initialCenter ?? CLLocationCoordinate2D(latitude: -25.4284, longitude: -49.2733), zoomLevel: initialZoom, animated: false)
		map.maximumZoomLevel = 19
		context.coordinator.map = map
		return map
	}

	func updateUIView(_ map: MLNMapView, context: Context) {
		let c = context.coordinator
		c.parent = self
		c.sync()
		if let flyTo, c.lastFly.map({ $0.latitude != flyTo.latitude || $0.longitude != flyTo.longitude }) ?? true {
			c.lastFly = flyTo
			map.setCenter(flyTo, zoomLevel: 16, animated: true)
		} else if c.lastFit != fitToken {
			c.lastFit = fitToken
			c.fitAll()
		}
	}

	@MainActor
	final class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate {
		var parent: TripMap?
		weak var map: MLNMapView?
		var lastFit = -1
		var lastFly: CLLocationCoordinate2D?
		private var styleReady = false
		/// A fit asked for before the map had its size and markers; done once it has finished loading.
		private var pendingFit = false
		private var shown: [String: Marker] = [:]
		private var trailKey = 0

		func mapView(_ map: MLNMapView, didFinishLoading style: MLNStyle) {
			let source = MLNShapeSource(identifier: "trails", shape: nil)
			style.addSource(source)
			let glow = MLNLineStyleLayer(identifier: "trails-glow", source: source)
			glow.lineColor = NSExpression(forConstantValue: UIColor(red: 1, green: 0.99, blue: 0.94, alpha: 1))
			glow.lineWidth = NSExpression(forConstantValue: 8)
			glow.lineOpacity = NSExpression(forConstantValue: 0.8)
			glow.lineCap = NSExpression(forConstantValue: "round")
			glow.lineJoin = NSExpression(forConstantValue: "round")
			style.addLayer(glow)
			let line = MLNLineStyleLayer(identifier: "trails", source: source)
			line.lineColor = NSExpression(mglJSONObject: ["to-color", ["get", "color"]])
			line.lineWidth = NSExpression(forConstantValue: 4)
			line.lineDashPattern = NSExpression(forConstantValue: [0.1, 2])
			line.lineCap = NSExpression(forConstantValue: "round")
			line.lineJoin = NSExpression(forConstantValue: "round")
			style.addLayer(line)
			styleReady = true
			trailKey = 0
			sync()
		}

		/// Adds, moves and removes markers and redraws the trails to match `parent`.
		func sync() {
			guard let map, let parent else { return }
			var wanted: [String: Marker] = [:]
			for it in parent.items {
				let color = parent.colors[it.userId] ?? .muted
				let m = Marker(key: "i:\(it.id)", coordinate: CLLocationCoordinate2D(latitude: it.lat, longitude: it.lng), kind: .item(it, color))
				wanted[m.key] = m
			}
			for p in parent.people {
				let m = Marker(key: "p:\(p.userId)|\(p.at)", coordinate: CLLocationCoordinate2D(latitude: p.lat, longitude: p.lng), kind: .person(p))
				wanted[m.key] = m
			}
			let gone = shown.filter { wanted[$0.key] == nil }
			map.removeAnnotations(Array(gone.values))
			for k in gone.keys { shown[k] = nil }
			let added = wanted.filter { shown[$0.key] == nil }.map(\.value)
			map.addAnnotations(added)
			for m in added { shown[m.key] = m }

			guard styleReady, let source = map.style?.source(withIdentifier: "trails") as? MLNShapeSource else { return }
			let key = parent.trails.hashValue
			guard key != trailKey else { return }
			trailKey = key
			let features = parent.trails.map { t -> MLNPolylineFeature in
				var coords = t.coordinates
				let f = MLNPolylineFeature(coordinates: &coords, count: UInt(coords.count))
				f.attributes = ["color": t.color]
				return f
			}
			source.shape = MLNShapeCollectionFeature(shapes: features)
		}

		func mapViewDidFinishLoadingMap(_ map: MLNMapView) {
			if pendingFit { pendingFit = false; fitAll() }
		}

		func fitAll() {
			guard let map, let parent else { return }
			guard styleReady, map.bounds.width > 0 else { pendingFit = true; return }
			var coords = parent.items.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
			coords += parent.people.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
			guard !coords.isEmpty else { return }
			if coords.count == 1 { return map.setCenter(coords[0], zoomLevel: 15, animated: true) }
			let lats = coords.map(\.latitude), lngs = coords.map(\.longitude)
			let bounds = MLNCoordinateBounds(sw: CLLocationCoordinate2D(latitude: lats.min()!, longitude: lngs.min()!),
											 ne: CLLocationCoordinate2D(latitude: lats.max()!, longitude: lngs.max()!))
			let camera = map.cameraThatFitsCoordinateBounds(bounds, edgePadding: UIEdgeInsets(top: 90, left: 60, bottom: 160, right: 60))
			map.fly(to: camera, withDuration: 0.8) { [weak map] in
				if let map, map.zoomLevel > 15 { map.setZoomLevel(15, animated: true) }
			}
		}

		func mapView(_ map: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
			guard let m = annotation as? Marker else { return nil }
			return MarkerView(marker: m)
		}

		func mapView(_ map: MLNMapView, didSelect annotation: MLNAnnotation) {
			map.deselectAnnotation(annotation, animated: false)
			guard let m = annotation as? Marker, case .item(let it, _) = m.kind else { return }
			switch it {
			case .media(let x): parent?.onOpen(.media(x.id))
			case .checkin(let x): parent?.onOpen(.checkin(x.id))
			}
		}

		func mapView(_ map: MLNMapView, regionDidChangeAnimated animated: Bool) {
			parent?.onCenter?(map.centerCoordinate)
		}

		func mapView(_ map: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool { false }
	}
}

/// A map marker: a post/check-in or a person's latest position.
final class Marker: NSObject, MLNAnnotation {
	enum Kind { case item(MapItem, Color), person(LatestLocation) }
	let key: String
	let coordinate: CLLocationCoordinate2D
	let kind: Kind

	init(key: String, coordinate: CLLocationCoordinate2D, kind: Kind) {
		self.key = key
		self.coordinate = coordinate
		self.kind = kind
	}

	var title: String? {
		switch kind {
		case .item(.media(let m), _): m.isVideo ? "Vídeo" : "Foto"
		case .item(.checkin, _): "Check-in"
		case .person(let p): p.name
		}
	}
}

/// Hosts the SwiftUI marker inside MapLibre's annotation view.
final class MarkerView: MLNAnnotationView {
	private var host: UIHostingController<AnyView>?

	init(marker: Marker) {
		super.init(reuseIdentifier: nil)
		let (view, size, bottomAnchored): (AnyView, CGSize, Bool) = {
			switch marker.kind {
			case .item(.media(let m), let color):
				(AnyView(PolaroidMarker(id: m.id, thumb: m.thumb, color: color, video: m.isVideo)), CGSize(width: 64, height: 72), false)
			case .item(.checkin, let color):
				(AnyView(PinMarker(color: color)), CGSize(width: 56, height: 64), true)
			case .person(let p):
				(AnyView(PersonMarker(person: p)), CGSize(width: 150, height: 74), true)
			}
		}()
		frame = CGRect(origin: .zero, size: size)
		let host = UIHostingController(rootView: view)
		host.view.backgroundColor = .clear
		host.view.frame = bounds
		host.view.isUserInteractionEnabled = false // MapLibre handles the tap (didSelect)
		addSubview(host.view)
		self.host = host
		// pins and people point at the spot with their bottom edge
		centerOffset = bottomAnchored ? CGVector(dx: 0, dy: -size.height / 2) : .zero
		if case .person = marker.kind { isEnabled = false }
		accessibilityLabel = marker.title
	}

	required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Marker looks (web map-markers.css)

/// Small stable tilt per id, so polaroids look hand-placed but don't jump around.
func tilt(for id: String) -> Double {
	var h: Int32 = 0
	for u in id.unicodeScalars { h = h &* 31 &+ Int32(truncatingIfNeeded: u.value) }
	return Double(Int(abs(Int(h))) % 9 - 4) * 1.2
}

struct PolaroidMarker: View {
	let id: String
	let thumb: URL?
	let color: Color
	let video: Bool
	@State private var shown = false

	var body: some View {
		ZStack {
			RemoteImage(url: thumb)
				.frame(width: 40, height: 38)
				.clipShape(RoundedRectangle(cornerRadius: 2))
			if video {
				Image(systemName: "play.fill").font(.system(size: 14)).foregroundStyle(.white).shadow(radius: 2)
			}
		}
		.padding(.horizontal, 4).padding(.top, 4).padding(.bottom, 9)
		.background(Color.polaroid)
		.overlay(alignment: .bottom) { Rectangle().fill(color).frame(height: 5) }
		.clipShape(RoundedRectangle(cornerRadius: 5))
		.shadow(color: .black.opacity(0.3), radius: 4, y: 3)
		.rotationEffect(.degrees(tilt(for: id)))
		.scaleEffect(shown ? 1 : 0.01)
		.offset(y: shown ? 0 : 20)
		.opacity(shown ? 1 : 0)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(Double.random(in: 0...0.4))) { shown = true } }
	}
}

/// Teardrop pin that drops in with a squash and a ripple.
struct PinMarker: View {
	let color: Color
	@State private var dropped = false

	var body: some View {
		ZStack(alignment: .bottom) {
			Ellipse().fill(.black.opacity(0.25)).frame(width: 18, height: 6).offset(y: 3)
				.scaleEffect(dropped ? 1 : 0.2)
			PinShape()
				.fill(color)
				.overlay(PinShape().stroke(.white, lineWidth: 3))
				.overlay(Circle().fill(.white).frame(width: 13, height: 13).offset(y: -9))
				.frame(width: 40, height: 52)
				.shadow(color: .black.opacity(0.18), radius: 0, y: 3)
				.offset(y: dropped ? 0 : -90)
				.opacity(dropped ? 1 : 0)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
		.onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.5).delay(Double.random(in: 0...0.4))) { dropped = true } }
	}
}

struct PinShape: Shape {
	func path(in r: CGRect) -> Path {
		// the web's SVG path, scaled from its 40×52 box
		let sx = r.width / 40, sy = r.height / 52
		func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
		var path = Path()
		path.move(to: p(20, 50))
		path.addCurve(to: p(36, 22), control1: p(20, 50), control2: p(36, 34.5))
		path.addArc(center: p(20, 22), radius: 16 * sx, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
		path.addCurve(to: p(20, 50), control1: p(4, 34.5), control2: p(20, 50))
		path.closeSubpath()
		return path
	}
}

/// Someone's latest position: their face, a name tag, a gentle bob; it glows while fresh (< 15 min).
struct PersonMarker: View {
	let person: LatestLocation

	private var fresh: Bool { (TripTime.date(person.at).map { Date().timeIntervalSince($0) < 15 * 60 }) ?? false }

	var body: some View {
		VStack(spacing: 3) {
			Text("\(person.name) · \(TripTime.ago(person.at))")
				.font(.text(11, .extraBold))
				.foregroundStyle(Color(red: 0.353, green: 0.271, blue: 0.188))
				.lineLimit(1)
				.padding(.horizontal, 8).padding(.vertical, 2)
				.background(Capsule().fill(Color(red: 1, green: 0.988, blue: 0.941)))
				.overlay(Capsule().strokeBorder(Color(red: 0.906, green: 0.859, blue: 0.722), lineWidth: 2))
			AvatarView(name: person.name, color: person.tint, photo: person.photo, size: 40)
				.overlay(Circle().strokeBorder(.white, lineWidth: 3.5))
				.opacity(fresh ? 1 : 0.8)
				.background {
					if fresh {
						Circle().fill(Color.sea.opacity(0.5))
							.phaseAnimator([false, true]) { v, on in v.scaleEffect(on ? 1.7 : 1).opacity(on ? 0 : 0.8) }
								animation: { on in on ? .easeOut(duration: 2) : .linear(duration: 0) }
					}
				}
		}
		.phaseAnimator([false, true]) { v, up in v.offset(y: up ? -5 : 0) } animation: { _ in .easeInOut(duration: 1.3) }
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
	}
}
