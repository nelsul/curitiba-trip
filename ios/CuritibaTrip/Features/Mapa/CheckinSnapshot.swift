import MapLibre
import SwiftUI

/// The picture of the map at a check-in (web map-snapshot.ts): island map, the person's pin with their face,
/// a "Nome · 19:56" label and the map attribution. Uploaded to /api/checkins/:id/snapshot for the diary.
enum CheckinSnapshot {
	private static let size = CGSize(width: 540, height: 360)

	/// Never throws: the diary shows a plain banner when there's no picture.
	@MainActor
	static func attach(checkinId: String, lat: Double, lng: Double, me: Me) async -> Bool {
		do {
			let jpeg = try await make(lat: lat, lng: lng, color: UIColor(me.tint), name: me.name, photo: me.photo, at: Date())
			let _: [String: String?] = try await API.shared.put("/api/checkins/\(checkinId)/snapshot", data: jpeg, contentType: "image/jpeg")
			return true
		} catch {
			return false
		}
	}

	@MainActor
	static func make(lat: Double, lng: Double, color: UIColor, name: String, photo: URL?, at: Date) async throws -> Data {
		let style = try await MapStyle.url()
		let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
		let options = MLNMapSnapshotOptions(styleURL: style, camera: MLNMapCamera(lookingAtCenter: center, altitude: 1000, pitch: 0, heading: 0), size: size)
		options.zoomLevel = 16
		options.scale = 2
		options.showsLogo = false
		let face = await loadFace(photo)

		let snapshotter = MLNMapSnapshotter(options: options)
		let map: UIImage = try await withCheckedThrowingContinuation { c in
			snapshotter.start { snapshot, error in
				if let image = snapshot?.image { c.resume(returning: image) }
				else { c.resume(throwing: error ?? APIError(status: 0, message: "mapa")) }
			}
		}
		_ = snapshotter // kept alive until the picture is ready

		let format = UIGraphicsImageRendererFormat()
		format.scale = 2
		let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
			let g = ctx.cgContext
			let W = size.width, H = size.height
			map.draw(in: CGRect(origin: .zero, size: size))

			// soft vignette so the pin pops
			let colors = [UIColor(red: 29 / 255, green: 42 / 255, blue: 69 / 255, alpha: 0).cgColor, UIColor(red: 10 / 255, green: 16 / 255, blue: 30 / 255, alpha: 0.35).cgColor]
			if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
				g.drawRadialGradient(grad, startCenter: CGPoint(x: W / 2, y: H / 2), startRadius: 80, endCenter: CGPoint(x: W / 2, y: H / 2), endRadius: W * 0.7, options: [.drawsAfterEndLocation])
			}

			// pin: tip exactly on the check-in point (the map center)
			let tip = CGPoint(x: W / 2, y: H / 2)
			let r: CGFloat = 30, headY = tip.y - 58
			UIColor.black.withAlphaComponent(0.25).setFill()
			UIBezierPath(ovalIn: CGRect(x: tip.x - 16, y: tip.y + 2 - 5, width: 32, height: 10)).fill()
			let pin = UIBezierPath()
			pin.move(to: tip)
			pin.addCurve(to: CGPoint(x: tip.x - r, y: headY), controlPoint1: CGPoint(x: tip.x - 14, y: tip.y - 18), controlPoint2: CGPoint(x: tip.x - r, y: headY + r * 0.6))
			pin.addArc(withCenter: CGPoint(x: tip.x, y: headY), radius: r, startAngle: .pi, endAngle: 0, clockwise: true)
			pin.addCurve(to: tip, controlPoint1: CGPoint(x: tip.x + r, y: headY + r * 0.6), controlPoint2: CGPoint(x: tip.x + 14, y: tip.y - 18))
			pin.close()
			color.setFill()
			pin.fill()
			pin.lineWidth = 4
			UIColor.white.setStroke()
			pin.stroke()

			// face (or initial) inside the pin head
			let fr = r - 6
			let faceRect = CGRect(x: tip.x - fr, y: headY - fr, width: fr * 2, height: fr * 2)
			if let face {
				g.saveGState()
				UIBezierPath(ovalIn: faceRect).addClip()
				face.draw(in: faceRect)
				g.restoreGState()
			} else {
				UIColor.white.setFill()
				UIBezierPath(ovalIn: faceRect).fill()
				let initial = String(name.prefix(1)).uppercased() as NSString
				let font = UIFont(name: "Fredoka-SemiBold", size: 26) ?? .boldSystemFont(ofSize: 26)
				let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
				let s = initial.size(withAttributes: attrs)
				initial.draw(at: CGPoint(x: tip.x - s.width / 2, y: headY - s.height / 2 + 1), withAttributes: attrs)
			}

			// label: "Nelson · 19:56"
			let label = "\(name) · \(at.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: TripTime.locale, timeZone: TripTime.zone)))" as NSString
			let labelFont = UIFont(name: "Fredoka-SemiBold", size: 17) ?? .boldSystemFont(ofSize: 17)
			let la: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: UIColor(red: 0.957, green: 0.933, blue: 0.839, alpha: 1)]
			let lw = label.size(withAttributes: la).width + 28
			let pill = UIBezierPath(roundedRect: CGRect(x: 14, y: H - 50, width: lw, height: 36), cornerRadius: 18)
			UIColor(red: 0.153, green: 0.216, blue: 0.353, alpha: 1).setFill()
			pill.fill()
			pill.lineWidth = 2.5
			UIColor(red: 0.227, green: 0.302, blue: 0.471, alpha: 1).setStroke()
			pill.stroke()
			let lh = label.size(withAttributes: la).height
			label.draw(at: CGPoint(x: 28, y: H - 32 - lh / 2), withAttributes: la)

			// (MapLibre already draws the map attribution required by the data license, bottom right)
		}
		guard let jpeg = image.jpegData(compressionQuality: 0.86) else { throw APIError(status: 0, message: "imagem") }
		return jpeg
	}

	private static func loadFace(_ url: URL?) async -> UIImage? {
		guard let url, let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
		return UIImage(data: data)
	}
}
