import CoreLocation
import Photos
import PhotosUI
import SwiftUI

/// Enviar (web /enviar): pick photos and videos from the library, add captions, and send the originals.
/// Sending continues in the background (see `Uploader`).
struct EnviarView: View {
	@State private var picked: [PhotosPickerItem] = []
	/// Kept outside the view so picked items survive switching tabs.
	@Bindable private var model = EnviarModel.shared
	private var drafts: [Draft] {
		get { model.drafts }
		nonmutating set { model.drafts = newValue }
	}
	private var here: (Double, Double)? {
		get { model.here }
		nonmutating set { model.here = newValue }
	}
	@State private var message: String?
	@State private var needsAccess = false
	@State private var camera: CameraPicker.Mode?
	@Environment(\.openURL) private var openURL
	private var uploader: Uploader { .shared }

	/// Use the phone's position only for things captured recently (same rule as the web).
	private static let freshWindow: TimeInterval = 2 * 3600

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				TitleRow(icon: .upload, title: "Enviar")
				Text("Fotos e vídeos vão no arquivo original, em qualidade total, com o local e a hora da própria foto. Pode fechar o app: o envio continua.")
					.font(.text(16)).foregroundStyle(Color.muted)

				PhotosPicker(selection: $picked, matching: .any(of: [.images, .videos]), preferredItemEncoding: .current, photoLibrary: .shared()) {
					PickerTile()
				}
				.buttonStyle(.plain)

				if UIImagePickerController.isSourceTypeAvailable(.camera) {
					HStack(spacing: 10) {
						Button { camera = .photo } label: { Label { Text("Tirar foto") } icon: { Icon(.camera, size: 20) } }
							.buttonStyle(.chunky(.secondary, fullWidth: true))
						Button { camera = .video } label: { Label { Text("Gravar vídeo") } icon: { Icon(.video, size: 20) } }
							.buttonStyle(.chunky(.secondary, fullWidth: true))
					}
				}

				if needsAccess {
					VStack(alignment: .leading, spacing: 8) {
						Text("Para enviar o original com o local, o app precisa ver todas as suas fotos.")
							.font(.text(15, .bold)).foregroundStyle(Color.ink)
						Button("Abrir Ajustes") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
							.buttonStyle(.chunky(.sea, small: true))
					}
					.card()
				}
				if let message { Text(message).font(.text(14, .bold)).foregroundStyle(Color.danger) }

				ForEach(model.drafts) { d in
					DraftRow(draft: binding(d), hereAvailable: here != nil) { drafts.removeAll { $0.id == d.id } }
						.popIn()
				}
				if !drafts.isEmpty {
					Button {
						send()
					} label: {
						Text("Enviar \(drafts.count) \(drafts.count == 1 ? "arquivo" : "arquivos")")
					}
					.buttonStyle(.chunky(.sun, fullWidth: true))
				}

				if !uploader.jobs.isEmpty {
					HStack {
						Text(uploader.isBusy ? "Enviando" : "Enviados").font(.display(20)).foregroundStyle(Color.ink)
						Spacer()
						if uploader.jobs.contains(where: { $0.state == .done }) {
							Button("Limpar enviados") { withAnimation { uploader.clearFinished() } }
								.buttonStyle(.chunky(.secondary, small: true))
						}
					}
					ForEach(uploader.jobs.reversed()) { job in JobRow(job: job) }
				}
			}
			.padding(16)
			.frame(maxWidth: 640)
			.frame(maxWidth: .infinity)
		}
		.scrollDismissesKeyboard(.interactively)
		.fullScreenCover(item: $camera) { mode in
			CameraPicker(mode: mode) { result in
				camera = nil
				if let result { Task { await addCaptured(result) } }
			}
			.ignoresSafeArea()
		}
		.onChange(of: picked) { _, items in
			guard !items.isEmpty else { return }
			Task { await add(items) }
		}
	}

	private func add(_ items: [PhotosPickerItem]) async {
		picked = []
		message = nil
		let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
		guard status == .authorized || status == .limited else { needsAccess = true; return }
		let ids = items.compactMap(\.itemIdentifier)
		let found = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
		var assets: [PHAsset] = []
		found.enumerateObjects { a, _, _ in assets.append(a) }
		// keep the order they were picked in
		assets.sort { (ids.firstIndex(of: $0.localIdentifier) ?? 0) < (ids.firstIndex(of: $1.localIdentifier) ?? 0) }
		if assets.count < ids.count {
			needsAccess = status == .limited
			if status != .limited { message = "Alguns itens não puderam ser abertos." }
		} else {
			needsAccess = false
		}
		var needHere = false
		for a in assets where !drafts.contains(where: { $0.id == a.localIdentifier }) {
			let fresh = a.creationDate.map { Date().timeIntervalSince($0) < Self.freshWindow } ?? true
			if a.location == nil && fresh { needHere = true }
			drafts.append(Draft(asset: a, useHere: a.location == nil && fresh))
		}
		if needHere && here == nil {
			do {
				let l = try await LocationOnce.current()
				here = (l.coordinate.latitude, l.coordinate.longitude)
			} catch {
				message = error.localizedDescription
				for i in drafts.indices { drafts[i].useHere = false }
			}
		}
	}

	/// A photo/video just taken in the app: saved to the phone's Photos (with where and when it was taken), then sent
	/// like any other picked item, so the original and its location go along.
	private func addCaptured(_ result: CameraPicker.Result) async {
		message = nil
		let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
		guard status == .authorized || status == .limited else { needsAccess = true; return }
		let location = try? await LocationOnce.current()
		do {
			let id = try await Self.saveToPhotos(result, location: location)
			guard let id, let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
				message = "Não foi possível salvar a foto."
				return
			}
			if let l = location { here = (l.coordinate.latitude, l.coordinate.longitude) }
			withAnimation { drafts.append(Draft(asset: asset, useHere: false)) }
		} catch {
			message = "Não foi possível salvar nas Fotos: \(error.localizedDescription)"
		}
	}

	nonisolated private static func saveToPhotos(_ result: CameraPicker.Result, location: CLLocation?) async throws -> String? {
		final class Box: @unchecked Sendable { var id: String? }
		let box = Box()
		try await PHPhotoLibrary.shared().performChanges {
			let req: PHAssetChangeRequest?
			switch result {
			case .photo(let img): req = PHAssetChangeRequest.creationRequestForAsset(from: img)
			case .video(let url): req = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
			}
			req?.creationDate = Date()
			req?.location = location
			box.id = req?.placeholderForCreatedAsset?.localIdentifier
		}
		return box.id
	}

	/// Looks the draft up by id on every access (index-based bindings crash when the list shrinks).
	private func binding(_ d: Draft) -> Binding<Draft> {
		Binding(
			get: { model.drafts.first { $0.id == d.id } ?? d },
			set: { new in if let i = model.drafts.firstIndex(where: { $0.id == d.id }) { model.drafts[i] = new } }
		)
	}

	private func send() {
		for d in drafts {
			uploader.add(assetId: d.id, caption: d.caption.trimmingCharacters(in: .whitespacesAndNewlines),
						 deviceLocation: d.asset.location == nil && d.useHere ? here : nil)
		}
		withAnimation { drafts = [] }
	}
}

@MainActor @Observable
final class EnviarModel {
	static let shared = EnviarModel()
	var drafts: [Draft] = []
	/// The phone's position, asked once when a picked item has no location of its own.
	var here: (Double, Double)?
}

/// A picked item before it's sent.
struct Draft: Identifiable {
	let asset: PHAsset
	var caption = ""
	var useHere: Bool
	var id: String { asset.localIdentifier }

	init(asset: PHAsset, useHere: Bool) {
		self.asset = asset
		self.useHere = useHere
	}
}

private struct PickerTile: View {
	var body: some View {
		VStack(spacing: 6) {
			Icon(.camera, size: 34)
				.foregroundStyle(.white)
				.frame(width: 64, height: 64)
				.background(RoundedRectangle(cornerRadius: 22).fill(Color.sea))
				.background(RoundedRectangle(cornerRadius: 22).fill(Color.seaDark).offset(y: 4))
				// scoped repeating animation (withAnimation(.repeatForever) here would also animate the scroll view)
				.phaseAnimator([-10.0, -2.0]) { v, a in v.rotationEffect(.degrees(a)) } animation: { _ in .easeInOut(duration: 1.5) }
			Text("Escolher fotos e vídeos").font(.display(19)).foregroundStyle(Color.ink)
			Text("Pode escolher vários de uma vez").font(.text(14)).foregroundStyle(Color.muted)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 26)
		.background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.surface))
		.overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.sea, style: StrokeStyle(lineWidth: 3, dash: [9, 6])))
		.contentShape(Rectangle())
		.accessibilityLabel("Escolher fotos e vídeos")
	}
}

private struct DraftRow: View {
	@Binding var draft: Draft
	let hereAvailable: Bool
	let remove: () -> Void
	@FocusState private var focused: Bool

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			AssetThumb(assetId: draft.id)
			VStack(alignment: .leading, spacing: 6) {
				HStack(alignment: .top) {
					Text(draft.asset.mediaType == .video ? "Vídeo" : "Foto").font(.text(16, .bold)).foregroundStyle(Color.ink)
					if let d = draft.asset.creationDate {
						Text(TripTime.short(d)).font(.text(13)).foregroundStyle(Color.muted).lineLimit(1)
					}
					Spacer()
					Button(action: remove) { Text("×").font(.system(size: 26)).foregroundStyle(Color.muted) }
						.frame(width: 36, height: 36).offset(x: 6, y: -8)
						.accessibilityLabel("Remover")
				}
				if draft.asset.location != nil {
					Label { Text("Local da foto") } icon: { Icon(.pin, size: 15) }
						.font(.text(14, .extraBold)).foregroundStyle(Color.leaf)
				} else if hereAvailable {
					Toggle(isOn: $draft.useHere) { Text("Usar minha localização atual").font(.text(14)).foregroundStyle(Color.ink) }
						.tint(.leaf)
				} else {
					Text("Sem local — dá para marcar depois").font(.text(14)).foregroundStyle(Color.muted)
				}
				TextField("Comentário (opcional)", text: $draft.caption, axis: .vertical)
					.lineLimit(1...4)
					.focused($focused)
					.submitLabel(.done)
					// Return closes the field (a caption is one paragraph)
					.onChange(of: draft.caption) { _, text in
						if text.contains("\n") { draft.caption = text.replacingOccurrences(of: "\n", with: ""); focused = false }
					}
					.font(.text(15)).foregroundStyle(Color.ink)
					.padding(10)
					.background(RoundedRectangle(cornerRadius: Radius.small).fill(Color.surface2))
					.overlay(RoundedRectangle(cornerRadius: Radius.small).strokeBorder(Color.line, lineWidth: 2))
			}
		}
		.card(padding: 12)
	}
}

private struct JobRow: View {
	let job: UploadJob
	private var uploader: Uploader { .shared }

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			AssetThumb(assetId: job.assetId)
			VStack(alignment: .leading, spacing: 4) {
				HStack(alignment: .top) {
					Text(job.name.isEmpty ? "Preparando…" : job.name).font(.text(16, .bold)).foregroundStyle(Color.ink).lineLimit(1)
					Spacer()
					if job.state != .done {
						Button { withAnimation { uploader.cancel(job.id) } } label: { Text("×").font(.system(size: 26)).foregroundStyle(Color.muted) }
							.frame(width: 36, height: 36).offset(x: 6, y: -8)
							.accessibilityLabel("Cancelar envio")
					}
				}
				if job.size > 0 {
					Text(bytes(job.size) + (job.hasLocation ? " · com local" : " · sem local"))
						.font(.text(13)).foregroundStyle(Color.muted)
				}
				if !job.caption.isEmpty { Text("“\(job.caption)”").font(.text(14)).foregroundStyle(Color.ink).lineLimit(2) }
				if job.state != .waiting && job.state != .preparing {
					UploadFlightView(progress: job.size > 0 ? Double(uploader.sent(job)) / Double(job.size) : 0,
									 done: job.state == .done, failed: job.state == .failed)
				}
				status
			}
		}
		.card(padding: 12)
		.opacity(job.state == .done ? 0.85 : 1)
	}

	@ViewBuilder private var status: some View {
		switch job.state {
		case .waiting: Text("Na fila").font(.text(13)).foregroundStyle(Color.muted)
		case .preparing: Text("Copiando o original…").font(.text(13)).foregroundStyle(Color.muted)
		case .uploading:
			Text("Voando… \(Int(Double(uploader.sent(job)) / Double(max(job.size, 1)) * 100))%").font(.text(13)).foregroundStyle(Color.muted)
		case .finishing: Text("Pousando…").font(.text(13)).foregroundStyle(Color.muted)
		case .done:
			if let id = job.mediaId {
				NavigationLink(value: Route.media(id)) {
					Text(job.duplicate ? "Já estava no diário · ver" : "Ver no diário").font(.text(14, .extraBold)).foregroundStyle(Color.sea)
				}
			}
		case .failed:
			VStack(alignment: .leading, spacing: 6) {
				Text(job.error ?? "Falhou.").font(.text(13, .bold)).foregroundStyle(Color.danger)
				Button("Tentar de novo") { uploader.retry(job.id) }.buttonStyle(.chunky(.sea, small: true))
			}
		}
	}

	private func bytes(_ n: Int64) -> String { ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }
}

/// A small polaroid of a library item.
struct AssetThumb: View {
	let assetId: String
	@State private var image: UIImage?
	@State private var isVideo = false

	var body: some View {
		ZStack {
			Color.track
			if let image { Image(uiImage: image).resizable().scaledToFill() }
			else { Icon(.camera, size: 26).foregroundStyle(Color.muted) }
			if isVideo {
				Icon(.play, size: 18).foregroundStyle(.white).shadow(radius: 2)
			}
		}
		.frame(width: 80, height: 80)
		.clipShape(RoundedRectangle(cornerRadius: 4))
		.padding(4)
		.background(RoundedRectangle(cornerRadius: 6).fill(Color.polaroid))
		.shadow(color: .black.opacity(0.25), radius: 4, y: 3)
		.rotationEffect(.degrees(-2))
		.task(id: assetId) { await load() }
	}

	private func load() async {
		guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject else { return }
		isVideo = asset.mediaType == .video
		let options = PHImageRequestOptions()
		options.deliveryMode = .opportunistic
		options.isNetworkAccessAllowed = true
		let size = CGSize(width: 240, height: 240)
		for await img in Self.images(asset, size, options) { image = img }
	}

	private static func images(_ asset: PHAsset, _ size: CGSize, _ options: PHImageRequestOptions) -> AsyncStream<UIImage> {
		AsyncStream { c in
			PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { img, info in
				if let img { c.yield(img) }
				let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
				if !degraded { c.finish() }
			}
		}
	}
}

/// The system camera, for a photo or a video.
struct CameraPicker: UIViewControllerRepresentable {
	enum Mode: String, Identifiable { case photo, video; var id: String { rawValue } }
	enum Result: @unchecked Sendable { case photo(UIImage), video(URL) }
	let mode: Mode
	let done: (Result?) -> Void

	func makeUIViewController(context: Context) -> UIImagePickerController {
		let c = UIImagePickerController()
		c.sourceType = .camera
		c.mediaTypes = [mode == .photo ? "public.image" : "public.movie"]
		c.cameraCaptureMode = mode == .photo ? .photo : .video
		c.videoQuality = .typeHigh
		c.delegate = context.coordinator
		return c
	}

	func updateUIViewController(_ c: UIImagePickerController, context: Context) {}
	func makeCoordinator() -> Coordinator { Coordinator(done: done) }

	final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
		let done: (Result?) -> Void
		init(done: @escaping (Result?) -> Void) { self.done = done }

		func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
			if let url = info[.mediaURL] as? URL { done(.video(url)) }
			else if let img = info[.originalImage] as? UIImage { done(.photo(img)) }
			else { done(nil) }
		}

		func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
	}
}
