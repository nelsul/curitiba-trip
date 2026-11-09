import Nuke
import SwiftUI
import UIKit

/// Share frames: up to 9 photos laid out on one image with a frame, for Instagram and WhatsApp.
/// Same layout as the web (web/src/lib/frames.ts) and Android (Frames.kt): keep the numbers in sync.
enum Frames {
	/// Decoration on top of the background; the shapes and sizes are described in web/src/lib/frames.ts.
	enum Deco { case none, line, airmail, film, ticket, dots }

	enum Style: String, CaseIterable, Identifiable {
		case polaroid, passaporte, noite, casamento, postal, filme, ingresso, porDoSol, araucaria
		var id: String { rawValue }

		struct Spec {
			let label: String
			let bg: UInt32
			var bg2: UInt32? = nil
			let card: UInt32, title: UInt32, sub: UInt32
			let line: UInt32?
			let deco: Deco
			let radius: CGFloat
			let text: (String, String)
		}

		var spec: Spec {
			switch self {
			case .polaroid: Spec(label: "Polaroid", bg: 0xffffff, card: 0xeeeeee, title: 0x1d2a45, sub: 0x3a4d78, line: nil, deco: .none, radius: 6, text: ("Curitiba", "11 a 18 de novembro de 2026"))
			case .passaporte: Spec(label: "Passaporte", bg: 0x18737a, card: 0x0f5a60, title: 0xfff6dc, sub: 0xf6d36b, line: 0xfff6dc, deco: .line, radius: 18, text: ("Viagem a Curitiba", "11–18 · novembro · 2026"))
			case .noite: Spec(label: "Noite", bg: 0x1d2a45, card: 0x27375a, title: 0xf6d36b, sub: 0xf4eed6, line: nil, deco: .none, radius: 22, text: ("Curitiba", "11 a 18 de novembro de 2026"))
			case .casamento: Spec(label: "Casamento", bg: 0xfff6dc, card: 0xf2e6c4, title: 0xf08bb0, sub: 0x1d2a45, line: 0xf08bb0, deco: .line, radius: 18, text: ("Casamento", "14 de novembro de 2026"))
			case .postal: Spec(label: "Cartão-postal", bg: 0xfbf3df, card: 0xefe3c2, title: 0x2f5aa8, sub: 0xd9534f, line: 0xd9534f, deco: .airmail, radius: 6, text: ("Lembranças de Curitiba", "11 a 18 de novembro de 2026"))
			case .filme: Spec(label: "Filme", bg: 0x141414, card: 0x262626, title: 0xf4eed6, sub: 0xf6d36b, line: 0xf4eed6, deco: .film, radius: 4, text: ("Curitiba", "11 a 18 · nov · 2026"))
			case .ingresso: Spec(label: "Ingresso", bg: 0xf6d36b, card: 0xe9c24f, title: 0x1d2a45, sub: 0x9a4a1e, line: 0x1d2a45, deco: .ticket, radius: 14, text: ("Curitiba", "Embarque 11/11 · Volta 18/11"))
			case .porDoSol: Spec(label: "Pôr do sol", bg: 0xf7a35c, bg2: 0x7b3f8f, card: 0xc8677a, title: 0xfff6dc, sub: 0xfff6dc, line: nil, deco: .none, radius: 24, text: ("Curitiba", "11 a 18 de novembro de 2026"))
			case .araucaria: Spec(label: "Araucária", bg: 0x2f5a40, card: 0x244a34, title: 0xf6d36b, sub: 0xe8f1d8, line: 0x8fc47a, deco: .dots, radius: 18, text: ("Curitiba", "Terra das araucárias · 2026"))
			}
		}
		var label: String { spec.label }
		var bg: UIColor { .init(hex: spec.bg) }
		var bg2: UIColor? { spec.bg2.map { UIColor(hex: $0) } }
		var title: UIColor { .init(hex: spec.title) }
	}

	enum Format: String, CaseIterable, Identifiable {
		case post, story
		var id: String { rawValue }
		var label: String { self == .post ? "Post (4:5)" : "Story (9:16)" }
		var size: CGSize { self == .post ? CGSize(width: 1080, height: 1350) : CGSize(width: 1080, height: 1920) }
	}

	static let max = 9
	static let pad: CGFloat = 56, footer: CGFloat = 200, gap: CGFloat = 14
	static let rows: [Int: [Int]] = [1: [1], 2: [1, 1], 3: [1, 2], 4: [2, 2], 5: [2, 3], 6: [2, 2, 2], 7: [2, 2, 3], 8: [3, 2, 3], 9: [3, 3, 3]]

	/// The subtitle when "Local e data" is on: "Jardim Botânico · 14 de novembro".
	static func caption(place: String, day: String) -> String {
		[place.trimmingCharacters(in: .whitespaces), day].filter { !$0.isEmpty }.joined(separator: " · ")
	}

	static func cells(_ n: Int, _ format: Format) -> [CGRect] {
		let W = format.size.width, H = format.size.height
		let r = rows[Swift.max(1, Swift.min(max, n))]!
		let aw = W - 2 * pad, ah = H - 2 * pad - footer
		let rh = (ah - gap * CGFloat(r.count - 1)) / CGFloat(r.count)
		var out: [CGRect] = []
		for (i, count) in r.enumerated() {
			let cw = (aw - gap * CGFloat(count - 1)) / CGFloat(count)
			for c in 0..<count { out.append(CGRect(x: pad + CGFloat(c) * (cw + gap), y: pad + CGFloat(i) * (rh + gap), width: cw, height: rh)) }
		}
		return out
	}

	private static func deco(_ s: Style.Spec, _ g: CGContext, _ W: CGFloat, _ H: CGFloat) {
		guard let lineHex = s.line else { return }
		let line = UIColor(hex: lineHex)
		g.saveGState()
		defer { g.restoreGState() }
		switch s.deco {
		case .none: break
		case .line:
			line.setStroke()
			let p = UIBezierPath(roundedRect: CGRect(x: 22, y: 22, width: W - 44, height: H - 44), cornerRadius: 30)
			p.lineWidth = 4
			p.stroke()
		case .airmail:
			var x = -H
			while x < W + H {
				for (dx, hex) in [(CGFloat(0), UInt32(0xd9534f)), (60, 0x2f5aa8)] {
					UIColor(hex: hex).setFill()
					let p = UIBezierPath()
					p.move(to: CGPoint(x: x + dx, y: 0))
					p.addLine(to: CGPoint(x: x + dx + 40, y: 0))
					p.addLine(to: CGPoint(x: x + dx + 40 - H, y: H))
					p.addLine(to: CGPoint(x: x + dx - H, y: H))
					p.close()
					p.fill()
				}
				x += 120
			}
			UIColor(hex: s.bg).setFill()
			g.fill(CGRect(x: 24, y: 24, width: W - 48, height: H - 48))
		case .film:
			line.setFill()
			var y: CGFloat = 30
			while y + 40 <= H - 20 {
				UIBezierPath(roundedRect: CGRect(x: 15, y: y, width: 26, height: 40), cornerRadius: 6).fill()
				UIBezierPath(roundedRect: CGRect(x: W - 41, y: y, width: 26, height: 40), cornerRadius: 6).fill()
				y += 70
			}
		case .ticket:
			let y = H - pad - footer + 26
			line.setStroke()
			let p = UIBezierPath()
			p.move(to: CGPoint(x: 44, y: y))
			p.addLine(to: CGPoint(x: W - 44, y: y))
			p.lineWidth = 4
			p.setLineDash([18, 14], count: 2, phase: 0)
			p.stroke()
			line.setFill()
			for x in [0, W] { UIBezierPath(ovalIn: CGRect(x: x - 30, y: y - 30, width: 60, height: 60)).fill() }
		case .dots:
			line.setFill()
			let inset: CGFloat = 30
			let dot = { (x: CGFloat, y: CGFloat) in UIBezierPath(ovalIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)).fill() }
			let nx = Int(((W - 2 * inset) / 34).rounded()), ny = Int(((H - 2 * inset) / 34).rounded())
			for i in 0...nx {
				let x = inset + (W - 2 * inset) * CGFloat(i) / CGFloat(nx)
				dot(x, inset)
				dot(x, H - inset)
			}
			for i in 1..<ny {
				let y = inset + (H - 2 * inset) * CGFloat(i) / CGFloat(ny)
				dot(inset, y)
				dot(W - inset, y)
			}
		}
	}

	/// Centered at the baseline, shrunk to fit the width if it's too long (as on the web).
	private static func fitText(_ text: String, font: UIFont, color: UIColor, baseline: CGFloat, width W: CGFloat, maxW: CGFloat) {
		var f = font
		let w = (text as NSString).size(withAttributes: [.font: f]).width
		if w > maxW { f = f.withSize(floor(f.pointSize * maxW / w)) }
		let center = NSMutableParagraphStyle()
		center.alignment = .center
		let s = NSAttributedString(string: text, attributes: [.font: f, .foregroundColor: color, .paragraphStyle: center])
		s.draw(in: CGRect(x: 0, y: baseline - f.ascender, width: W, height: f.lineHeight + 10))
	}

	/// `caption` replaces the style's subtitle (the "Local e data" option).
	static func render(_ photos: [UIImage], style: Style, format: Format, caption: String? = nil) -> UIImage {
		let size = format.size
		let s = style.spec
		let fmt = UIGraphicsImageRendererFormat()
		fmt.scale = 1
		return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
			let g = ctx.cgContext
			if let bg2 = s.bg2,
			   let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(hex: s.bg).cgColor, UIColor(hex: bg2).cgColor] as CFArray, locations: [0, 1]) {
				g.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
			} else {
				UIColor(hex: s.bg).setFill()
				g.fill(CGRect(origin: .zero, size: size))
			}
			deco(s, g, size.width, size.height)
			for (img, c) in zip(photos, cells(photos.count, format)) {
				g.saveGState()
				let clip = UIBezierPath(roundedRect: c, cornerRadius: s.radius)
				UIColor(hex: s.card).setFill()
				clip.fill()
				clip.addClip()
				let k = Swift.max(c.width / img.size.width, c.height / img.size.height)
				let w = img.size.width * k, h = img.size.height * k
				img.draw(in: CGRect(x: c.midX - w / 2, y: c.midY - h / 2, width: w, height: h))
				g.restoreGState()
			}
			// baselines at H - pad - 92 and H - pad - 34 (as on the web)
			let maxW = size.width - 2 * pad - 40
			fitText(s.text.0, font: UIFont(name: "Fredoka-SemiBold", size: 76) ?? .boldSystemFont(ofSize: 76), color: UIColor(hex: s.title),
					baseline: size.height - pad - 92, width: size.width, maxW: maxW)
			fitText(caption?.isEmpty == false ? caption! : s.text.1, font: UIFont(name: "Nunito-ExtraBold", size: 34) ?? .boldSystemFont(ofSize: 34),
					color: UIColor(hex: s.sub), baseline: size.height - pad - 34, width: size.width, maxW: maxW)
		}
	}
}

extension UIColor {
	convenience init(hex: UInt32) {
		self.init(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
	}
}

/// Picks a frame style and format for the chosen photos, then shares the image (Instagram, WhatsApp, Fotos…).
struct FrameMakerView: View {
	let items: [FeedMedia]
	@Environment(\.dismiss) private var dismiss
	@State private var photos: [UIImage] = []
	@State private var style: Frames.Style = .polaroid
	@State private var format: Frames.Format = .post
	@State private var error: String?
	/// "Local e data": where you are now (the trip's place or the neighborhood) and today's date
	@State private var withPlace = false
	@State private var place = ""
	@State private var locating = false
	private let today: String = {
		var f = Date.FormatStyle(locale: TripTime.locale, timeZone: TripTime.zone).day().month(.wide)
		f.timeZone = TripTime.zone
		return Date().formatted(f)
	}()
	private var caption: String? { withPlace ? Frames.caption(place: place, day: today) : nil }

	private var image: UIImage? { photos.isEmpty ? nil : Frames.render(photos, style: style, format: format, caption: caption) }

	var body: some View {
		NavigationStack {
			VStack(spacing: 14) {
				Group {
					if let image {
						Image(uiImage: image).resizable().scaledToFit()
							.clipShape(RoundedRectangle(cornerRadius: 12))
							.accessibilityLabel("Prévia da imagem com \(items.count) \(items.count == 1 ? "foto" : "fotos")")
					} else if let error {
						Text(error).font(.text(15, .bold)).foregroundStyle(Color.danger)
					} else {
						ProgressView("Preparando as fotos…").tint(.sea).foregroundStyle(Color.muted)
					}
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 8) {
						ForEach(Frames.Style.allCases) { s in
							Chip(selected: style == s, action: { style = s }) {
								HStack(spacing: 6) {
									RoundedRectangle(cornerRadius: 4)
										.fill(LinearGradient(colors: [Color(uiColor: s.bg), Color(uiColor: s.bg2 ?? s.bg)], startPoint: .top, endPoint: .bottom))
										.frame(width: 14, height: 14)
										.overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(uiColor: s.title), lineWidth: 2))
									Text(s.label)
								}
							}
						}
					}
					.padding(.horizontal, 4)
				}
				.fixedSize(horizontal: false, vertical: true)
				HStack(spacing: 8) {
					ForEach(Frames.Format.allCases) { f in Chip(selected: format == f, action: { format = f }) { Text(f.label) } }
				}
				VStack(spacing: 8) {
					HStack(spacing: 8) {
						Chip(selected: withPlace, action: togglePlace) {
							HStack(spacing: 6) { Icon(.pin, size: 16); Text("Local e data") }
						}
						.fixedSize()
						if withPlace { Text(today).font(.text(14, .bold)).foregroundStyle(Color.muted).lineLimit(1).fixedSize() }
					}
					if withPlace {
						TextField(locating ? "Procurando onde você está…" : "Onde vocês estão?", text: $place)
							.font(.text(16)).foregroundStyle(Color.ink)
							.padding(.horizontal, 14).frame(minHeight: 42)
							.background(Capsule().fill(Color.surface))
							.overlay(Capsule().strokeBorder(Color.line, lineWidth: 2))
							.onChange(of: place) { if place.count > 40 { place = String(place.prefix(40)) } }
					}
				}
				if let image {
					ShareLink(item: Image(uiImage: image), preview: SharePreview("Curitiba", image: Image(uiImage: image))) {
						Label { Text("Compartilhar") } icon: { Icon(.share, size: 18) }
					}
					.buttonStyle(.chunky(.sun, fullWidth: true))
				}
				Text("Abre o Instagram, o WhatsApp, Salvar nas Fotos e os outros apps.").font(.text(13)).foregroundStyle(Color.muted)
			}
			.padding(16)
			.background(Color.bg)
			.navigationTitle("Moldura")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
			.task { await load() }
		}
		.tint(.sea)
	}

	private func togglePlace() {
		withPlace.toggle()
		guard withPlace, place.isEmpty else { return }
		locating = true
		Task {
			defer { locating = false }
			// where you are now; else where the first photo was taken; else Curitiba
			var at: (Double, Double)?
			if let l = try? await LocationOnce.current() { at = (l.coordinate.latitude, l.coordinate.longitude) }
			else if let m = items.first(where: { $0.lat != nil && $0.lng != nil }) { at = (m.lat!, m.lng!) }
			guard let at else { place = "Curitiba"; return }
			struct Here: Decodable { let name: String }
			let here: Here? = try? await API.shared.get("/api/places/here", query: ["lat": String(at.0), "lng": String(at.1)])
			if place.isEmpty { place = here?.name ?? "Curitiba" }
		}
	}

	private func load() async {
		do {
			var out: [UIImage] = []
			for m in items {
				// from the image cache when the photo was already seen (it usually was: it was just picked in the grid)
				guard let req = MediaCache.imageRequest(m.image) else { continue }
				out.append(try await ImagePipeline.shared.image(for: req))
			}
			if out.isEmpty { error = "Não foi possível carregar as fotos." }
			photos = out
		} catch {
			self.error = "Não foi possível carregar as fotos. Confira a internet."
		}
	}
}
