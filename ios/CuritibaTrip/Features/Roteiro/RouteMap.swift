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

/// The day's map (web RouteMap): numbered pins (or the place's photo) and the route by street between them,
/// colored by how you get there; walking legs and straight lines (no street route found) are dashed.
struct RouteMap: UIViewRepresentable {
	let styleURL: URL
	let date: String
	let points: [RoutePoint]
	var onPick: (Int) -> Void = { _ in }

	func makeCoordinator() -> Coordinator { Coordinator() }

	func makeUIView(context: Context) -> MLNMapView {
		let map = MLNMapView(frame: .zero, styleURL: styleURL)
		map.delegate = context.coordinator
		map.logoView.isHidden = true
		map.attributionButtonPosition = .bottomRight
		map.backgroundColor = UIColor(Color.bg)
		map.maximumZoomLevel = 18
		if let first = points.first { map.setCenter(first.coordinate, zoomLevel: 13, animated: false) }
		context.coordinator.map = map
		return map
	}

	func updateUIView(_ map: MLNMapView, context: Context) {
		let c = context.coordinator
		c.parent = self
		if c.shown != points || c.date != date {
			c.shown = points
			c.date = date
			c.reload()
		}
	}

	@MainActor
	final class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate {
		var parent: RouteMap?
		weak var map: MLNMapView?
		var shown: [RoutePoint] = []
		var date = ""
		private var styleReady = false
		private var lastSize = CGSize.zero
		private var routeTask: Task<Void, Never>?

		func mapView(_ map: MLNMapView, didFinishLoading style: MLNStyle) {
			let source = MLNShapeSource(identifier: "route", shape: nil)
			style.addSource(source)
			let casing = MLNLineStyleLayer(identifier: "route-casing", source: source)
			casing.lineColor = NSExpression(forConstantValue: UIColor(red: 1, green: 0.99, blue: 0.94, alpha: 1))
			casing.lineWidth = NSExpression(forConstantValue: 8)
			casing.lineOpacity = NSExpression(forConstantValue: 0.85)
			casing.lineCap = NSExpression(forConstantValue: "round")
			casing.lineJoin = NSExpression(forConstantValue: "round")
			style.addLayer(casing)
			for dashed in [false, true] {
				let line = MLNLineStyleLayer(identifier: dashed ? "route-dashed" : "route", source: source)
				line.predicate = NSPredicate(format: "dashed == %@", NSNumber(value: dashed))
				line.lineColor = NSExpression(mglJSONObject: ["to-color", ["get", "color"]])
				line.lineWidth = NSExpression(forConstantValue: 4.5)
				line.lineCap = NSExpression(forConstantValue: dashed ? "butt" : "round")
				line.lineJoin = NSExpression(forConstantValue: "round")
				if dashed { line.lineDashPattern = NSExpression(forConstantValue: [1, 1.6]) }
				style.addLayer(line)
			}
			styleReady = true
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
			fit()
			guard styleReady else { return }
			routeTask?.cancel()
			let date = parent.date
			let count = parent.points.count
			routeTask = Task { [weak self] in
				guard count >= 2, let route: DayRoute = try? await API.shared.get("/api/roteiro/days/\(date)/route") else {
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
				f.attributes = ["color": UIColor(t.color).hexString, "dashed": NSNumber(value: !leg.routed || t == .pe)]
				return f
			}
			source.shape = MLNShapeCollectionFeature(shapes: features)
		}

		func fit() {
			guard let map, let parent, map.bounds.width > 0 else { return }
			let coords = parent.points.map(\.coordinate)
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
			guard let a = annotation as? StopAnnotation else { return nil }
			return StopPinView(point: a.point)
		}

		func mapView(_ map: MLNMapView, didSelect annotation: MLNAnnotation) {
			map.deselectAnnotation(annotation, animated: false)
			if let a = annotation as? StopAnnotation { parent?.onPick(a.point.n) }
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
