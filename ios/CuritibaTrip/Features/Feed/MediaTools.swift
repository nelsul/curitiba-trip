import Photos
import SwiftUI

/// Instagram-style zoom: pinch a photo with two fingers and it grows under the fingers and follows them as they
/// move, springing back when they lift. iOS 18+ uses UIKit's pinch (it knows where the fingers are); iOS 17 only scales.
struct PinchToZoom: ViewModifier {
	@State private var scale: CGFloat = 1
	@State private var offset: CGSize = .zero
	@State private var anchor: UnitPoint = .center
	@State private var size: CGSize = .zero
	/// iOS 17 fallback: resets by itself when the pinch ends or is cancelled, e.g. by the scroll view
	@GestureState(resetTransaction: Transaction(animation: .spring(duration: 0.3))) private var legacyScale: CGFloat = 1

	func body(content: Content) -> some View {
		if #available(iOS 18.0, *) {
			content
				.scaleEffect(scale, anchor: anchor)
				.offset(offset)
				.zIndex(scale > 1 ? 1 : 0)
				.onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
				.gesture(PinchRecognizer(
					onBegan: { p in
						// where the fingers started: the zoom grows from there
						if size.width > 0, size.height > 0 { anchor = UnitPoint(x: p.x / size.width, y: p.y / size.height) }
					},
					onChanged: { s, move in scale = min(5, max(1, s)); offset = move },
					onEnded: { withAnimation(.spring(duration: 0.3)) { scale = 1; offset = .zero } }
				))
		} else {
			content
				.scaleEffect(legacyScale, anchor: anchor)
				.zIndex(legacyScale > 1 ? 1 : 0)
				.simultaneousGesture(
					MagnifyGesture()
						.updating($legacyScale) { v, s, _ in s = min(5, max(1, v.magnification)) }
						.onChanged { v in anchor = v.startAnchor }
				)
		}
	}
}

/// UIKit's two-finger pinch: how much it grew and how far the point between the fingers moved. Works alongside
/// scroll views and paging (the reels, the Diário), which keep their one-finger swipes.
@available(iOS 18.0, *)
private struct PinchRecognizer: UIGestureRecognizerRepresentable {
	let onBegan: (CGPoint) -> Void
	let onChanged: (CGFloat, CGSize) -> Void
	let onEnded: () -> Void

	final class Coordinator: NSObject, UIGestureRecognizerDelegate {
		var start: CGPoint = .zero
		/// the scroll views around the photo (the Diário, the reels pages), frozen while pinching so they don't scroll too
		var frozen: [UIScrollView] = []

		/// every scroll view under the fingers (the recognizer isn't always attached inside them)
		func freeze(_ g: UIGestureRecognizer) {
			guard let window = g.view?.window else { return }
			let p = g.location(in: window)
			func walk(_ v: UIView) {
				guard !v.isHidden, v.convert(v.bounds, to: window).contains(p) else { return }
				if let sv = v as? UIScrollView, sv.isScrollEnabled {
					sv.isScrollEnabled = false // also cancels a scroll that already started
					frozen.append(sv)
				}
				v.subviews.forEach(walk)
			}
			walk(window)
		}

		func unfreeze() {
			for sv in frozen { sv.isScrollEnabled = true }
			frozen = []
		}
		func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
	}

	func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

	func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
		let g = UIPinchGestureRecognizer()
		g.delegate = context.coordinator
		return g
	}

	func handleUIGestureRecognizerAction(_ g: UIPinchGestureRecognizer, context: Context) {
		let p = context.converter.localLocation
		switch g.state {
		case .began:
			context.coordinator.start = p
			context.coordinator.freeze(g)
			onBegan(p)
			onChanged(g.scale, .zero)
		case .changed:
			// a finger lifted: UIKit reports the remaining one, which would jump; keep the last position
			guard g.numberOfTouches >= 2 else { return }
			let s = context.coordinator.start
			onChanged(g.scale, CGSize(width: p.x - s.x, height: p.y - s.y))
		default:
			context.coordinator.unfreeze()
			onEnded()
		}
	}
}

extension View {
	func pinchToZoom() -> some View { modifier(PinchToZoom()) }
}

/// Downloads the original file (full quality, as uploaded) and adds it to the phone's Photos.
enum OriginalSaver {
	struct Failure: Error, LocalizedError {
		let message: String
		var errorDescription: String? { message }
	}
	private struct Link: Decodable { let url: URL; let name: String }

	static func save(_ media: FeedMedia) async throws {
		let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
		guard status == .authorized || status == .limited else {
			throw Failure(message: "Sem permissão para salvar nas Fotos. Ative em Ajustes › Viagem › Fotos.")
		}
		// the signed link, then the file straight from storage (without our token)
		let link: Link = try await API.shared.get("/api/media/\(media.id)/original", query: ["link": "1"])
		let (tmp, resp) = try await URLSession.shared.download(from: link.url)
		guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw Failure(message: "Não foi possível baixar o original.") }
		let file = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-\(link.name)")
		try FileManager.default.moveItem(at: tmp, to: file)
		defer { try? FileManager.default.removeItem(at: file) }
		let isVideo = media.isVideo
		let name = link.name
		let asNew = saveAsNew
		try await PHPhotoLibrary.shared().performChanges {
			let options = PHAssetResourceCreationOptions()
			options.originalFilename = name
			let req = PHAssetCreationRequest.forAsset()
			req.addResource(with: isVideo ? .video : .photo, fileURL: file, options: options)
			// "Salvar como foto nova": today's date, so it shows at the top of Photos (not back on the day it was taken)
			if asNew { req.creationDate = Date() }
		}
	}

	/// Mais › "Salvar originais como fotos novas" (on by default).
	static let saveAsNewKey = "salvar-como-nova"
	static var saveAsNew: Bool { UserDefaults.standard.object(forKey: saveAsNewKey) as? Bool ?? true }
}

/// "Salvar original": a download icon that turns into a spinner, then a check when it's in Photos.
struct SaveOriginalButton: View {
	let media: FeedMedia
	var color: Color = .ink
	var size: CGFloat = 24
	@State private var state = 0 // 0 idle · 1 saving · 2 saved
	@State private var error: String?

	var body: some View {
		Button {
			guard state == 0 else { return }
			state = 1
			Task {
				do {
					try await OriginalSaver.save(media)
					withAnimation { state = 2 }
					try? await Task.sleep(for: .seconds(2.5))
					withAnimation { state = 0 }
				} catch {
					state = 0
					self.error = error.localizedDescription
				}
			}
		} label: {
			Group {
				switch state {
				case 1: ProgressView().tint(color)
				case 2: Icon(.check, size: size).foregroundStyle(Color.leaf)
				default: Icon(.download, size: size).foregroundStyle(color)
				}
			}
			.frame(width: 44, height: 44)
		}
		.buttonStyle(.plain)
		.accessibilityLabel(state == 2 ? "Salvo nas Fotos" : "Salvar original nas Fotos")
		.alert("Não foi possível salvar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
			Button("OK", role: .cancel) {}
		} message: { Text(error ?? "") }
	}
}
