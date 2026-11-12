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

				WifiOnlyCard()

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
					DraftRow(draft: binding(d), here: here, locateHere: locateHere) { drafts.removeAll { $0.id == d.id } }
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
			drafts.append(Draft(asset: a, loc: a.location != nil ? .photo : fresh ? .here : .none))
		}
		if needHere && here == nil {
			do {
				let l = try await LocationOnce.current()
				here = (l.coordinate.latitude, l.coordinate.longitude)
			} catch {
				message = error.localizedDescription
				for i in drafts.indices where drafts[i].loc == .here { drafts[i].loc = .none }
			}
		}
	}

	/// "Onde estou agora" on a row while the position isn't known yet: ask for it once.
	private func locateHere() async -> Bool {
		if here != nil { return true }
		do {
			let l = try await LocationOnce.current()
			here = (l.coordinate.latitude, l.coordinate.longitude)
			return true
		} catch {
			message = error.localizedDescription
			return false
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
			withAnimation { drafts.append(Draft(asset: asset, loc: asset.location != nil ? .photo : .none)) }
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
						 deviceLocation: d.loc == .here ? here : nil, overPhoto: d.loc == .here && d.asset.location != nil,
						 wifiOnly: UploadNetwork.shared.wifiOnly)
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
	/// where the post goes on the map: the photo's own GPS, where the phone is now, or nowhere
	enum Loc { case photo, here, none }
	var loc: Loc
	var id: String { asset.localIdentifier }

	init(asset: PHAsset, loc: Loc) {
		self.asset = asset
		self.loc = loc
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
	let here: (Double, Double)?
	let locateHere: () async -> Bool
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
				LocationChoice(draft: $draft, here: here, locateHere: locateHere)
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
		case .uploading where job.waitsForWifi && !UploadNetwork.shared.onWifi:
			VStack(alignment: .leading, spacing: 6) {
				Label { Text(job.previewSent == true ? "Esperando Wi‑Fi · a prévia já está no diário" : "Esperando Wi‑Fi") } icon: { Icon(.clock, size: 14) }
					.font(.text(13, .bold)).foregroundStyle(Color.sky)
				Button("Enviar agora") { uploader.sendNow(job.id) }.buttonStyle(.chunky(.secondary, small: true))
			}
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

/// "Enviar só no Wi-Fi": the originals wait for Wi-Fi (a low-res preview goes to the diary right away).
private struct WifiOnlyCard: View {
	@Bindable private var network = UploadNetwork.shared

	var body: some View {
		Toggle(isOn: $network.wifiOnly) {
			VStack(alignment: .leading, spacing: 2) {
				Text("Enviar só no Wi‑Fi").font(.text(16, .bold)).foregroundStyle(Color.ink)
				Text("Fora do Wi‑Fi, vai para o diário uma prévia leve; o original sobe sozinho quando o celular entrar no Wi‑Fi. Dá para mandar um agora em “Enviar agora”.")
					.font(.text(13)).foregroundStyle(Color.muted)
			}
		}
		.tint(.leaf)
		.card()
	}
}

/// Where a post goes on the map, chosen before sending: "Onde a foto foi tirada" (its own GPS), "Onde estou agora"
/// (the phone's position) or "Sem local", with the place's name, so a photo taken earlier isn't pinned by mistake.
private struct LocationChoice: View {
	@Binding var draft: Draft
	let here: (Double, Double)?
	let locateHere: () async -> Bool
	@State private var names = PlaceNames.shared

	private var photoCoord: (Double, Double)? { draft.asset.location.map { ($0.coordinate.latitude, $0.coordinate.longitude) } }
	private var old: Bool { draft.asset.creationDate.map { Date().timeIntervalSince($0) > 2 * 3600 } ?? false }

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 6) {
					if photoCoord != nil { option(.photo, .camera, "Onde a foto foi tirada") }
					option(.here, .locate, "Onde estou agora")
					if photoCoord == nil { option(.none, nil, "Sem local") }
				}
			}
			Group {
				switch draft.loc {
				case .photo:
					line(name(photoCoord) ?? "Local da foto", "gravado na própria foto")
				case .here where here != nil:
					line(name(here) ?? "Sua localização", "onde você está agora")
					if old, let d = draft.asset.creationDate {
						Text("A foto é de \(TripTime.short(d)): confira se foi tirada aqui.")
							.font(.text(13, .bold)).foregroundStyle(Color.sun).fixedSize(horizontal: false, vertical: true)
					}
				default:
					Text(draft.asset.mediaType == .video ? "Sem local (se o vídeo tiver, ele é usado)" : "Sem local — dá para marcar depois, no mapa")
						.font(.text(13)).foregroundStyle(Color.muted)
				}
			}
		}
		.task(id: "\(draft.loc)|\(here?.0 ?? 0)|\(here?.1 ?? 0)") {
			if let c = draft.loc == .photo ? photoCoord : here { await names.load(c) }
		}
	}

	private func name(_ c: (Double, Double)?) -> String? { c.flatMap { names.name($0) } }

	private func line(_ place: String, _ how: String) -> some View {
		HStack(spacing: 4) {
			Icon(.pin, size: 14).foregroundStyle(Color.leaf)
			(Text(place).font(.text(14, .extraBold)).foregroundStyle(Color.leaf) + Text(" · \(how)").font(.text(13)).foregroundStyle(Color.muted))
		}
	}

	private func option(_ value: Draft.Loc, _ icon: IconName?, _ label: String) -> some View {
		let on = draft.loc == value
		return Button {
			Task {
				if value == .here, !(await locateHere()) { return }
				draft.loc = value
			}
		} label: {
			HStack(spacing: 5) {
				if let icon { Icon(icon, size: 14) }
				Text(label)
			}
			.font(.text(13, .extraBold))
			.foregroundStyle(on ? Color.onLeaf : Color.ink)
			.padding(.horizontal, 10).frame(minHeight: 32)
			.background(Capsule().fill(on ? Color.leaf : Color.surface2))
			.overlay(Capsule().strokeBorder(on ? Color.leaf : Color.line, lineWidth: 2))
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(on ? .isSelected : [])
	}
}

/// Names for coordinates (GET /api/places/here), cached for the session.
@MainActor @Observable
final class PlaceNames {
	static let shared = PlaceNames()
	private var cache: [String: String] = [:]
	private var asked: Set<String> = []
	private struct Here: Decodable { let name: String }
	private func key(_ c: (Double, Double)) -> String { String(format: "%.4f,%.4f", c.0, c.1) }

	func name(_ c: (Double, Double)) -> String? { cache[key(c)] }

	func load(_ c: (Double, Double)) async {
		let k = key(c)
		guard !asked.contains(k) else { return }
		asked.insert(k)
		if let h: Here = try? await API.shared.get("/api/places/here", query: ["lat": String(c.0), "lng": String(c.1)]), !h.name.isEmpty { cache[k] = h.name }
	}
}
