import SwiftUI
import UIKit

/// Share frames: up to 9 photos laid out on one image with a frame, for Instagram and WhatsApp.
/// Same layout as the web (web/src/lib/frames.ts) and Android (Frames.kt): keep the numbers in sync.
enum Frames {
	enum Style: String, CaseIterable, Identifiable {
		case polaroid, passaporte, noite, casamento
		var id: String { rawValue }
		var label: String { switch self { case .polaroid: "Polaroid"; case .passaporte: "Passaporte"; case .noite: "Noite"; case .casamento: "Casamento" } }
		var bg: UIColor { switch self { case .polaroid: .init(hex: 0xffffff); case .passaporte: .init(hex: 0x18737a); case .noite: .init(hex: 0x1d2a45); case .casamento: .init(hex: 0xfff6dc) } }
		var card: UIColor { switch self { case .polaroid: .init(hex: 0xeeeeee); case .passaporte: .init(hex: 0x0f5a60); case .noite: .init(hex: 0x27375a); case .casamento: .init(hex: 0xf2e6c4) } }
		var title: UIColor { switch self { case .polaroid: .init(hex: 0x1d2a45); case .passaporte: .init(hex: 0xfff6dc); case .noite: .init(hex: 0xf6d36b); case .casamento: .init(hex: 0xf08bb0) } }
		var sub: UIColor { switch self { case .polaroid: .init(hex: 0x3a4d78); case .passaporte: .init(hex: 0xf6d36b); case .noite: .init(hex: 0xf4eed6); case .casamento: .init(hex: 0x1d2a45) } }
		var line: UIColor? { switch self { case .passaporte: .init(hex: 0xfff6dc); case .casamento: .init(hex: 0xf08bb0); default: nil } }
		var radius: CGFloat { switch self { case .polaroid: 6; case .noite: 22; default: 18 } }
		var text: (String, String) {
			switch self {
			case .polaroid, .noite: ("Curitiba", "11 a 18 de novembro de 2026")
			case .passaporte: ("Viagem a Curitiba", "11–18 · novembro · 2026")
			case .casamento: ("Casamento", "14 de novembro de 2026")
			}
		}
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

	static func render(_ photos: [UIImage], style: Style, format: Format) -> UIImage {
		let size = format.size
		let fmt = UIGraphicsImageRendererFormat()
		fmt.scale = 1
		return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
			let g = ctx.cgContext
			style.bg.setFill()
			g.fill(CGRect(origin: .zero, size: size))
			if let line = style.line {
				line.setStroke()
				let p = UIBezierPath(roundedRect: CGRect(x: 22, y: 22, width: size.width - 44, height: size.height - 44), cornerRadius: 30)
				p.lineWidth = 4
				p.stroke()
			}
			for (img, c) in zip(photos, cells(photos.count, format)) {
				g.saveGState()
				let clip = UIBezierPath(roundedRect: c, cornerRadius: style.radius)
				style.card.setFill()
				clip.fill()
				clip.addClip()
				let k = Swift.max(c.width / img.size.width, c.height / img.size.height)
				let w = img.size.width * k, h = img.size.height * k
				img.draw(in: CGRect(x: c.midX - w / 2, y: c.midY - h / 2, width: w, height: h))
				g.restoreGState()
			}
			let center = NSMutableParagraphStyle()
			center.alignment = .center
			let title = NSAttributedString(string: style.text.0, attributes: [.font: UIFont(name: "Fredoka-SemiBold", size: 76) ?? .boldSystemFont(ofSize: 76), .foregroundColor: style.title, .paragraphStyle: center])
			let sub = NSAttributedString(string: style.text.1, attributes: [.font: UIFont(name: "Nunito-ExtraBold", size: 34) ?? .boldSystemFont(ofSize: 34), .foregroundColor: style.sub, .paragraphStyle: center])
			// baselines at H - pad - 92 and H - pad - 34 (as on the web)
			let titleFont = UIFont(name: "Fredoka-SemiBold", size: 76) ?? .boldSystemFont(ofSize: 76)
			let subFont = UIFont(name: "Nunito-ExtraBold", size: 34) ?? .boldSystemFont(ofSize: 34)
			title.draw(in: CGRect(x: 0, y: size.height - pad - 92 - titleFont.ascender, width: size.width, height: 100))
			sub.draw(in: CGRect(x: 0, y: size.height - pad - 34 - subFont.ascender, width: size.width, height: 50))
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

	private var image: UIImage? { photos.isEmpty ? nil : Frames.render(photos, style: style, format: format) }

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
									RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: s.bg)).frame(width: 14, height: 14)
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

	private func load() async {
		do {
			var out: [UIImage] = []
			for m in items {
				guard let url = m.image else { continue }
				let (data, _) = try await URLSession.shared.data(from: url)
				if let img = UIImage(data: data) { out.append(img) }
			}
			if out.isEmpty { error = "Não foi possível carregar as fotos." }
			photos = out
		} catch {
			self.error = "Não foi possível carregar as fotos. Confira a internet."
		}
	}
}
