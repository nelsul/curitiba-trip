import MapLibre
import SwiftUI

/// One numbered stop on the day's map.
struct RoutePoint: Hashable {
	let n: Int
	let name: String
	let coordinate: CLLocationCoordinate2D
	let photo: URL?
	let visited: Bool

	static func == (a: RoutePoint, b: RoutePoint) -> Bool {
		a.n == b.n && a.name == b.name && a.photo == b.photo && a.visited == b.visited
			&& a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude
	}
	func hash(into h: inout Hasher) { h.combine(n); h.combine(name); h.combine(visited); h.combine(coordinate.latitude); h.combine(coordinate.longitude) }
}

/// Where the person sleeps: the day leaves from there ("start") and/or comes back there ("end").
struct RouteHome: Hashable {
	let id: String
	let name: String
	let emoji: String
	let label: String
	let coordinate: CLLocationCoordinate2D

	static func == (a: RouteHome, b: RouteHome) -> Bool {
		a.id == b.id && a.name == b.name && a.label == b.label
			&& a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude
	}
	func hash(into h: inout Hasher) { h.combine(id); h.combine(coordinate.latitude); h.combine(coordinate.longitude) }
}

/// The day's map (web RouteMap): numbered pins (or the place's photo) and the route by street between them,
/// colored by how you get there; walking legs and straight lines (no street route found) are dashed.
struct RouteMap: UIViewRepresentable {
	let styleURL: URL
	let date: String
	let points: [RoutePoint]
	var homes: [RouteHome] = []
	/// the selected stop: the leg to it stands out, the others fade
	var active: Int? = nil
	var onPick: (Int) -> Void = { _ in }
	var onPickHome: (String) -> Void = { _ in }

	func makeCoordinator() -> Coordinator { Coordinator() }

	func makeUIView(context: Context) -> MLNMapView {
		let map = MLNMapView(frame: .zero, styleURL: styleURL)
		map.delegate = context.coordinator
		map.logoView.isHidden = true
		map.attributionButtonPosition = .bottomRight
		map.backgroundColor = UIColor(Color.bg)
		map.maximumZoomLevel = 18
		if let first = homes.first?.coordinate ?? points.first?.coordinate { map.setCenter(first, zoomLevel: 13, animated: false) }
		context.coordinator.map = map
		return map
	}

	func updateUIView(_ map: MLNMapView, context: Context) {
		let c = context.coordinator
		c.parent = self
		if c.shown != points || c.homes != homes || c.date != date {
			c.shown = points
			c.homes = homes
			c.date = date
			c.reload()
		}
		if c.active != active {
			c.active = active
			c.highlight()
		}
	}

	@MainActor
	final class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate {
		var parent: RouteMap?
		weak var map: MLNMapView?
		var shown: [RoutePoint] = []
		var homes: [RouteHome] = []
		var date = ""
		var active: Int?
		private var styleReady = false
		private var lastSize = CGSize.zero
		private var routeTask: Task<Void, Never>?

		func mapView(_ map: MLNMapView, didFinishLoading style: MLNStyle) {
			let source = MLNShapeSource(identifier: "route", shape: nil)
			style.addSource(source)
			let casing = MLNLineStyleLayer(identifier: "route-casing", source: source)
			casing.predicate = NSPredicate(format: "back == NO")
			casing.lineColor = NSExpression(forConstantValue: UIColor(red: 1, green: 0.99, blue: 0.94, alpha: 1))
			casing.lineWidth = NSExpression(forConstantValue: 8)
			casing.lineOpacity = NSExpression(forConstantValue: 0.85)
			casing.lineCap = NSExpression(forConstantValue: "round")
			casing.lineJoin = NSExpression(forConstantValue: "round")
			style.addLayer(casing)
			for dashed in [false, true] {
				let line = MLNLineStyleLayer(identifier: dashed ? "route-dashed" : "route", source: source)
				line.predicate = NSPredicate(format: "dashed == %@ AND back == NO", NSNumber(value: dashed))
				line.lineColor = NSExpression(mglJSONObject: ["to-color", ["get", "color"]])
				line.lineWidth = NSExpression(forConstantValue: 4.5)
				line.lineCap = NSExpression(forConstantValue: dashed ? "butt" : "round")
				line.lineJoin = NSExpression(forConstantValue: "round")
				if dashed { line.lineDashPattern = NSExpression(forConstantValue: [1, 1.6]) }
				style.addLayer(line)
			}
			// the way back to the stay: a row of dots, so it doesn't look like the way out
			let back = MLNLineStyleLayer(identifier: "route-back", source: source)
			back.predicate = NSPredicate(format: "back == YES")
			back.lineColor = NSExpression(mglJSONObject: ["to-color", ["get", "color"]])
			back.lineWidth = NSExpression(forConstantValue: 5)
			back.lineCap = NSExpression(forConstantValue: "round")
			back.lineJoin = NSExpression(forConstantValue: "round")
			back.lineDashPattern = NSExpression(forConstantValue: [0, 2])
			style.addLayer(back)
			// the leg to the selected stop, wider and coral, on top
			let hotCasing = MLNLineStyleLayer(identifier: "route-hot-casing", source: source)
			hotCasing.lineColor = NSExpression(forConstantValue: UIColor(red: 1, green: 0.99, blue: 0.94, alpha: 1))
			hotCasing.lineWidth = NSExpression(forConstantValue: 13)
			let hot = MLNLineStyleLayer(identifier: "route-hot", source: source)
			hot.lineColor = NSExpression(forConstantValue: UIColor(Color.coral))
			hot.lineWidth = NSExpression(forConstantValue: 7)
			for l in [hotCasing, hot] {
				l.lineCap = NSExpression(forConstantValue: "round")
				l.lineJoin = NSExpression(forConstantValue: "round")
				l.predicate = NSPredicate(format: "to == -1")
				style.addLayer(l)
			}
			styleReady = true
			highlight()
			reload()
		}

		func mapViewDidFinishLoadingMap(_ map: MLNMapView) { fit() }

		/// The map's size changed (rotation, sheets): show the whole day again.
		func mapView(_ map: MLNMapView, regionDidChangeAnimated animated: Bool) {
			if map.bounds.size != lastSize, map.bounds.width > 0 {
				lastSize = map.bounds.size
				fit()
			}
		}

		func reload() {
			guard let map, let parent else { return }
			map.removeAnnotations(map.annotations ?? [])
			map.addAnnotations(parent.points.map { StopAnnotation(point: $0) })
			map.addAnnotations(parent.homes.map { HomeAnnotation(home: $0) })
			fit()
			guard styleReady else { return }
			routeTask?.cancel()
			// with "casa" the server also draws the way from and back to where you sleep
			let path = "/api/roteiro/days/\(parent.date)/route"
			let query: [String: String?] = parent.homes.isEmpty ? [:] : ["casa": "1"]
			let count = parent.points.count + parent.homes.count
			routeTask = Task { [weak self] in
				guard count >= 2, let route: DayRoute = try? await API.shared.get(path, query: query) else {
					self?.setRoute([])
					return
				}
				guard !Task.isCancelled else { return }
				self?.setRoute(route.legs)
			}
		}

		private func setRoute(_ legs: [DayRoute.Leg]) {
			guard let source = map?.style?.source(withIdentifier: "route") as? MLNShapeSource else { return }
			let features = legs.compactMap { leg -> MLNPolylineFeature? in
				var coords = leg.coordinates.compactMap { $0.count == 2 ? CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) : nil }
				guard coords.count >= 2 else { return nil }
				let f = MLNPolylineFeature(coordinates: &coords, count: UInt(coords.count))
				let t = RoteiroTransport.of(leg.transport)
				f.attributes = ["color": UIColor(t.color).hexString, "dashed": NSNumber(value: !leg.routed || t == .pe),
								"back": NSNumber(value: leg.back == true), "to": NSNumber(value: leg.to ?? -1)]
				return f
			}
			source.shape = MLNShapeCollectionFeature(shapes: features)
		}

		/// Shows the leg to the selected stop and fades the rest (web RouteMap does the same).
		func highlight() {
			guard styleReady, let style = map?.style else { return }
			let pred = NSPredicate(format: "to == %@", NSNumber(value: active ?? -1))
			for id in ["route-hot-casing", "route-hot"] { (style.layer(withIdentifier: id) as? MLNLineStyleLayer)?.predicate = pred }
			let fade = active == nil ? 1.0 : 0.35
			for id in ["route", "route-dashed", "route-back"] {
				(style.layer(withIdentifier: id) as? MLNLineStyleLayer)?.lineOpacity = NSExpression(forConstantValue: fade)
			}
			(style.layer(withIdentifier: "route-casing") as? MLNLineStyleLayer)?.lineOpacity = NSExpression(forConstantValue: 0.85 * fade)
		}

		func fit() {
			guard let map, let parent, map.bounds.width > 0 else { return }
			let coords = parent.points.map(\.coordinate) + parent.homes.map(\.coordinate)
			guard let first = coords.first else { return }
			if coords.count == 1 { return map.setCenter(first, zoomLevel: 15, animated: false) }
			let lats = coords.map(\.latitude), lngs = coords.map(\.longitude)
			let bounds = MLNCoordinateBounds(sw: CLLocationCoordinate2D(latitude: lats.min()!, longitude: lngs.min()!),
											 ne: CLLocationCoordinate2D(latitude: lats.max()!, longitude: lngs.max()!))
			let camera = map.cameraThatFitsCoordinateBounds(bounds, edgePadding: UIEdgeInsets(top: 50, left: 40, bottom: 50, right: 40))
			map.setCamera(camera, animated: false)
			if map.zoomLevel > 15 { map.setZoomLevel(15, animated: false) }
		}

		func mapView(_ map: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
			if let h = annotation as? HomeAnnotation { return HomePinView(home: h.home) }
			guard let a = annotation as? StopAnnotation else { return nil }
			return StopPinView(point: a.point)
		}

		func mapView(_ map: MLNMapView, didSelect annotation: MLNAnnotation) {
			map.deselectAnnotation(annotation, animated: false)
			if let a = annotation as? StopAnnotation { parent?.onPick(a.point.n) }
			if let h = annotation as? HomeAnnotation { parent?.onPickHome(h.home.id) }
		}

		func mapView(_ map: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool { false }
	}
}

final class StopAnnotation: NSObject, MLNAnnotation {
	let point: RoutePoint
	init(point: RoutePoint) { self.point = point }
	var coordinate: CLLocationCoordinate2D { point.coordinate }
	var title: String? { "\(point.n). \(point.name)" }
}

final class HomeAnnotation: NSObject, MLNAnnotation {
	let home: RouteHome
	init(home: RouteHome) { self.home = home }
	var coordinate: CLLocationCoordinate2D { home.coordinate }
	var title: String? { "\(home.label): \(home.name)" }
}

/// The stay on the map: its emoji on a sea-blue rounded square.
final class HomePinView: MLNAnnotationView {
	private var host: UIHostingController<AnyView>?

	init(home: RouteHome) {
		super.init(reuseIdentifier: nil)
		frame = CGRect(x: 0, y: 0, width: 44, height: 44)
		let host = UIHostingController(rootView: AnyView(
			Text(home.emoji).font(.system(size: 20))
				.frame(width: 38, height: 38)
				.background(RoundedRectangle(cornerRadius: 12).fill(Color.sea))
				.overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(red: 1, green: 0.99, blue: 0.94), lineWidth: 3))
				.shadow(color: .black.opacity(0.3), radius: 0, y: 3)))
		host.view.backgroundColor = .clear
		host.view.frame = bounds
		host.view.isUserInteractionEnabled = false
		addSubview(host.view)
		self.host = host
		accessibilityLabel = "\(home.label): \(home.name)"
	}

	required init?(coder: NSCoder) { fatalError() }
}

/// Hosts the SwiftUI pin inside MapLibre's annotation view.
final class StopPinView: MLNAnnotationView {
	private var host: UIHostingController<StopPin>?

	init(point: RoutePoint) {
		super.init(reuseIdentifier: nil)
		let size: CGFloat = point.photo != nil ? 54 : 38
		frame = CGRect(x: 0, y: 0, width: size, height: size)
		let host = UIHostingController(rootView: StopPin(point: point))
		host.view.backgroundColor = .clear
		host.view.frame = bounds
		host.view.isUserInteractionEnabled = false
		addSubview(host.view)
		self.host = host
		accessibilityLabel = "\(point.n). \(point.name)\(point.visited ? " (já fomos)" : "")"
	}

	required init?(coder: NSCoder) { fatalError() }
}

/// Yellow numbered circle, or the place's photo in a round frame with the number on a badge; ✓ when visited.
struct StopPin: View {
	let point: RoutePoint

	var body: some View {
		ZStack {
			if let photo = point.photo {
				RemoteImage(url: photo)
					.frame(width: 44, height: 44)
					.clipShape(Circle())
					.overlay(Circle().strokeBorder(Color(red: 1, green: 0.99, blue: 0.94), lineWidth: 3))
					.overlay(alignment: .topLeading) { badge(Text("\(point.n)"), fill: .sun, ink: .onSun).offset(x: -4, y: -4) }
			} else {
				Text("\(point.n)").font(.display(15)).foregroundStyle(point.visited ? Color.onLeaf : Color.onSun)
					.frame(width: 30, height: 30)
					.background(Circle().fill(point.visited ? Color.leaf : Color.sun))
					.overlay(Circle().strokeBorder(Color(red: 1, green: 0.99, blue: 0.94), lineWidth: 3))
			}
		}
		.overlay(alignment: .bottomTrailing) {
			if point.visited { badge(Text("✓"), fill: .leaf, ink: .onLeaf).offset(x: 4, y: 4) }
		}
		.shadow(color: .black.opacity(0.3), radius: 0, y: 3)
	}

	private func badge(_ t: Text, fill: Color, ink: Color) -> some View {
		t.font(.text(11, .extraBold)).foregroundStyle(ink)
			.frame(width: 20, height: 20)
			.background(Circle().fill(fill))
			.overlay(Circle().strokeBorder(Color(red: 1, green: 0.99, blue: 0.94), lineWidth: 2))
	}
}

extension UIColor {
	/// "#rrggbb" for MapLibre style expressions.
	var hexString: String {
		var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
		getRed(&r, green: &g, blue: &b, alpha: &a)
		return String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
	}
}
