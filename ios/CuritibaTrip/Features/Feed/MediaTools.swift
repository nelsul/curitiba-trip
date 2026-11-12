import Photos
import SwiftUI

/// Instagram-style zoom: pinch a photo with two fingers and it grows under the fingers, springing back when they lift.
struct PinchToZoom: ViewModifier {
	/// resets by itself (with a spring) when the pinch ends or is cancelled, e.g. by the scroll view
	@GestureState(resetTransaction: Transaction(animation: .spring(duration: 0.3))) private var scale: CGFloat = 1
	@State private var anchor: UnitPoint = .center

	func body(content: Content) -> some View {
		content
			.scaleEffect(scale, anchor: anchor)
			.zIndex(scale > 1 ? 1 : 0)
			.simultaneousGesture(
				MagnifyGesture()
					.updating($scale) { v, s, _ in s = min(5, max(1, v.magnification)) }
					.onChanged { v in anchor = v.startAnchor }
			)
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
		try await PHPhotoLibrary.shared().performChanges {
			let options = PHAssetResourceCreationOptions()
			options.originalFilename = name
			PHAssetCreationRequest.forAsset().addResource(with: isVideo ? .video : .photo, fileURL: file, options: options)
		}
	}
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
