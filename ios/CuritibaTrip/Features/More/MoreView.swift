import PhotosUI
import SwiftUI

/// Mais (web /mais): profile photo (circle framer), devices, admin link, sign out.
struct MoreView: View {
	@Environment(AppState.self) private var app
	@Environment(\.openURL) private var openURL
	@State private var pick: PhotosPickerItem?
	@State private var cropping: UIImage?
	@State private var savingPhoto = false
	@State private var devices: [Device] = []
	@State private var error: String?

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				TitleRow(icon: .user, title: "Mais")
				if let me = app.me {
					HStack(spacing: 16) {
						PhotosPicker(selection: $pick, matching: .images) {
							AvatarView(name: me.name, color: me.tint, photo: me.photo, size: 88)
								.overlay(alignment: .bottomTrailing) {
									Icon(.camera, size: 16).foregroundStyle(Color.onSun)
										.frame(width: 32, height: 32)
										.background(Circle().fill(Color.sun))
										.overlay(Circle().strokeBorder(Color.surface, lineWidth: 3))
										.rotationEffect(.degrees(savingPhoto ? 8 : 0))
										.animation(savingPhoto ? .easeInOut(duration: 0.25).repeatForever() : .default, value: savingPhoto)
								}
						}
						.accessibilityLabel("Trocar a minha foto")
						VStack(alignment: .leading, spacing: 2) {
							Text(me.name).font(.display(26)).foregroundStyle(Color.ink)
							if me.isAdmin { Text("Administrador").font(.text(14)).foregroundStyle(Color.muted) }
							Text("Toque na foto para trocar.").font(.text(14)).foregroundStyle(Color.muted)
						}
						Spacer()
					}
					.card()
				}
				if let error { Text(error).font(.text(14, .bold)).foregroundStyle(Color.danger) }

				VStack(alignment: .leading, spacing: 10) {
					Text("Aparelhos conectados").font(.display(20)).foregroundStyle(Color.ink)
					ForEach(devices) { d in
						HStack {
							VStack(alignment: .leading, spacing: 0) {
								Text((d.deviceName ?? "iPhone") + (d.current ? " (este)" : "")).font(.text(16, .bold)).foregroundStyle(Color.ink)
								if let last = d.lastUsedAt { Text("Usado \(TripTime.ago(last))").font(.text(13)).foregroundStyle(Color.muted) }
							}
							Spacer()
							if !d.current {
								Button("Sair") { Task { await revoke(d) } }.buttonStyle(.chunky(.danger, small: true))
							}
						}
					}
					if devices.isEmpty { Text("Só este iPhone.").font(.text(14)).foregroundStyle(Color.muted) }
				}
				.card()

				AlertsCard()

				if app.me?.isAdmin == true {
					Button { openURL(API.shared.base.appending(path: "/admin")) } label: { Text("Gerenciar pessoas (site)") }
						.buttonStyle(.chunky(.secondary, fullWidth: true))
				}
				Button { Task { await app.signOut() } } label: { Text("Sair") }
					.buttonStyle(.chunky(.secondary, fullWidth: true))
			}
			.padding(16)
			.frame(maxWidth: 640)
			.frame(maxWidth: .infinity)
		}
		.task { await loadDevices() }
		.onChange(of: pick) { _, item in
			guard let item else { return }
			Task {
				if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { cropping = img.flattened(maxSide: 2048) }
				else { error = "Não foi possível abrir essa imagem." }
				pick = nil
			}
		}
		.fullScreenCover(item: Binding(get: { cropping.map(CropItem.init) }, set: { if $0 == nil { cropping = nil } })) { item in
			AvatarCropper(image: item.image) { jpeg in
				cropping = nil
				Task { await upload(jpeg) }
			} cancel: { cropping = nil }
		}
	}

	private func loadDevices() async {
		if let list: [Device] = try? await API.shared.get("/api/devices") { devices = list }
	}

	private func revoke(_ d: Device) async {
		do { try await API.shared.delete("/api/devices/\(d.id)"); await loadDevices() } catch { self.error = error.localizedDescription }
	}

	private func upload(_ jpeg: Data) async {
		guard let me = app.me else { return }
		savingPhoto = true
		defer { savingPhoto = false }
		do {
			let _: [String: String?] = try await API.shared.put("/api/users/\(me.id)/avatar", data: jpeg, contentType: "image/jpeg")
			await app.reloadMe()
			app.feedChanged()
			error = nil
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}
}

private struct CropItem: Identifiable { let image: UIImage; var id: ObjectIdentifier { ObjectIdentifier(image) } }

/// Circle framer (web AvatarCropper): drag to move, pinch or slider to zoom; the image always covers the circle.
struct AvatarCropper: View {
	let image: UIImage
	let done: (Data) -> Void
	let cancel: () -> Void
	private let stage: CGFloat = 300
	@State private var scale: CGFloat = 1 // multiple of the "cover" scale
	@State private var baseScale: CGFloat = 1
	@State private var offset: CGSize = .zero
	@State private var baseOffset: CGSize = .zero

	private var cover: CGFloat { stage / min(image.size.width, image.size.height) }
	private var shown: CGSize { CGSize(width: image.size.width * cover * scale, height: image.size.height * cover * scale) }

	var body: some View {
		VStack(spacing: 16) {
			Text("Ajustar foto").font(.display(26)).foregroundStyle(Color.ink)
			Text("Arraste para mover e use o controle (ou dois dedos) para aproximar.")
				.font(.text(15)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
			Color.clear
				.overlay { Image(uiImage: image).resizable().frame(width: shown.width, height: shown.height).offset(offset) }
				.overlay {
					// dim everything outside the circle (even-odd: the square minus the circle), then the dashed guide
					Canvas { ctx, size in
						let r = CGRect(origin: .zero, size: size)
						var dim = Path(r)
						dim.addEllipse(in: r)
						ctx.fill(dim, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
						ctx.stroke(Path(ellipseIn: r.insetBy(dx: 1.5, dy: 1.5)), with: .color(.white.opacity(0.85)),
								   style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
					}
					.allowsHitTesting(false)
				}
			.frame(width: stage, height: stage)
			.clipShape(RoundedRectangle(cornerRadius: 18))
			.contentShape(Rectangle())
			.gesture(
				DragGesture()
					.onChanged { v in offset = clamp(CGSize(width: baseOffset.width + v.translation.width, height: baseOffset.height + v.translation.height)) }
					.onEnded { _ in baseOffset = offset }
					.simultaneously(with: MagnifyGesture()
						.onChanged { setScale(baseScale * $0.magnification) }
						.onEnded { _ in baseScale = scale })
			)
			HStack {
				Icon(.camera, size: 16).foregroundStyle(Color.muted)
				Slider(value: Binding(get: { scale }, set: { setScale($0); baseScale = $0 }), in: 1...6).tint(.sea)
				Text("\(Int(scale * 100))%").font(.text(13)).foregroundStyle(Color.muted).frame(width: 46)
			}
			.frame(width: stage)
			HStack {
				Button("Cancelar", action: cancel).buttonStyle(.chunky(.secondary))
				Spacer()
				Button("Usar foto") { done(render()) }.buttonStyle(.chunky(.sun))
			}
			.frame(width: stage)
		}
		.padding(20)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(DottedBackground())
	}

	private func setScale(_ s: CGFloat) {
		scale = max(1, min(6, s))
		offset = clamp(offset)
		baseOffset = offset
	}

	/// Keep the circle covered: the image edge can't move inside the stage.
	private func clamp(_ o: CGSize) -> CGSize {
		let maxX = (shown.width - stage) / 2, maxY = (shown.height - stage) / 2
		return CGSize(width: min(maxX, max(-maxX, o.width)), height: min(maxY, max(-maxY, o.height)))
	}

	/// The square under the circle, at up to 512 px, as JPEG.
	private func render() -> Data {
		let k = cover * scale // displayed points per image point
		let side = stage / k
		let origin = CGPoint(x: (image.size.width - side) / 2 - offset.width / k, y: (image.size.height - side) / 2 - offset.height / k)
		let out = min(512, side * image.scale)
		let renderer = UIGraphicsImageRenderer(size: CGSize(width: out, height: out), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
		let img = renderer.image { _ in
			let r = out / side
			image.draw(in: CGRect(x: -origin.x * r, y: -origin.y * r, width: image.size.width * r, height: image.size.height * r))
		}
		return img.jpegData(compressionQuality: 0.88) ?? Data()
	}
}

extension UIImage {
	/// A plain SDR bitmap no bigger than `maxSide`, upright. Big HDR originals otherwise render as tiled layers
	/// that SwiftUI overlays can't cover, and they waste memory.
	func flattened(maxSide: CGFloat) -> UIImage {
		let k = min(1, maxSide / max(size.width, size.height))
		let target = CGSize(width: (size.width * k).rounded(), height: (size.height * k).rounded())
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.preferredRange = .standard
		return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
	}
}

/// Mais › "Avisos e localização": one switch per kind of notification, and the background location.
private struct AlertsCard: View {
	private var location: LocationSharing { .shared }
	@State private var activity = Notifier.shared.isOn(.activity)
	@State private var itinerary = Notifier.shared.isOn(.itinerary)
	@State private var arrival = Notifier.shared.isOn(.arrival)
	@State private var background = UserDefaults.standard.bool(forKey: "localizacao-segundo-plano")

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Avisos e localização").font(.display(20)).foregroundStyle(Color.ink)
			row("Novidades do grupo", "Fotos, check-ins, comentários e curtidas nos seus posts (confere de tempos em tempos).", $activity) { on in
				Task { await Notifier.shared.set(.activity, on) }
			}
			row("Lembretes do roteiro", "30 minutos antes de cada parada com horário.", $itinerary) { on in
				Task { await Notifier.shared.set(.itinerary, on) }
			}
			Divider().overlay(Color.line)
			row("Meu caminho com o app fechado", "O grupo vê no mapa por onde você passou, mesmo com o app fechado. Gasta pouca bateria. Precisa da localização \"Sempre\".", $background) { on in
				location.setBackground(on)
				if !on, arrival { arrival = false; Task { await Notifier.shared.set(.arrival, false) } }
			}
			row("Avisar quando chegar", "Ao chegar num lugar do roteiro: \"Chegou? Fazer check-in\".", $arrival) { on in
				Task { await Notifier.shared.set(.arrival, on) }
			}
			.disabled(!background)
			.opacity(background ? 1 : 0.5)
			if let e = location.error { Text(e).font(.text(13, .bold)).foregroundStyle(Color.danger) }
		}
		.card()
	}

	private func row(_ title: String, _ detail: String, _ value: Binding<Bool>, changed: @escaping (Bool) -> Void) -> some View {
		Toggle(isOn: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0; changed($0) })) {
			VStack(alignment: .leading, spacing: 2) {
				Text(title).font(.text(16, .bold)).foregroundStyle(Color.ink)
				Text(detail).font(.text(13)).foregroundStyle(Color.muted)
			}
		}
		.tint(.leaf)
	}
}
