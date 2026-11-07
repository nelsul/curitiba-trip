import AVKit
import Photos
import SwiftUI

enum Route: Hashable {
	case media(String)
	case checkin(String)
}

/// Photo/video page (web /m/:id): polaroid viewer, likes, caption, file info, save original, delete, comments.
struct MediaDetailView: View {
	let id: String
	@Environment(AppState.self) private var app
	@Environment(\.dismiss) private var dismiss
	@State private var detail: MediaDetail?
	@State private var error: String?
	@State private var editing = false
	@State private var saving: String?
	@State private var zoom = false
	@State private var confirmDelete = false

	var body: some View {
		ScrollView {
			if let d = detail {
				let item = d.item
				let person = app.person(item.userId)
				let mine = item.userId == app.me?.id
				VStack(alignment: .leading, spacing: 16) {
					viewer(item)
					HStack(spacing: 2) {
						LikeButton(liked: d.likers.contains(app.me?.id ?? "")) { liked in Task { await like(liked) } }
						LikedByView(likers: d.likers)
					}
					.padding(.leading, -8)
					HStack(spacing: 10) {
						AvatarView(name: person?.name ?? "?", color: person?.tint ?? .muted, photo: person?.photo, size: 44)
						VStack(alignment: .leading, spacing: 0) {
							Text(person?.name ?? "Alguém").font(.display(19))
							Text("\(TripTime.longDay(TripTime.dayKey(item.at))), \(TripTime.time(item.at))\(item.takenAtSource == "upload" ? " (hora do envio)" : "")")
								.font(.text(14)).foregroundStyle(Color.muted)
						}
					}
					.foregroundStyle(Color.ink)
					if !item.caption.isEmpty {
						Text(item.caption).font(.text(17)).foregroundStyle(Color.ink)
							.padding(.horizontal, 14).padding(.vertical, 10)
							.frame(maxWidth: .infinity, alignment: .leading)
							.card(padding: 0, radius: 18)
					}
					if mine {
						Button(item.caption.isEmpty ? "Adicionar texto" : "Editar texto") { editing = true }
							.font(.text(15, .extraBold)).tint(.leaf)
					}
					if let lat = item.lat, let lng = item.lng {
						HStack(spacing: 12) {
							Icon(.pin, size: 18).foregroundStyle(Color.sea)
							Text(locationLabel(item.locationSource)).font(.text(14)).foregroundStyle(Color.muted)
							Spacer()
							Link("Google Maps", destination: URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)")!)
								.font(.text(14, .extraBold)).tint(.leaf)
						}
					}
					VStack(alignment: .leading, spacing: 10) {
						Text(fileLine(item)).font(.text(13)).foregroundStyle(Color.muted)
						HStack(spacing: 10) {
							Button { Task { await saveOriginal(item) } } label: {
								Label { Text(saving ?? "Salvar original nas Fotos") } icon: { Icon(.download, size: 18) }
							}
							.buttonStyle(.chunky(.sea, small: true))
							.disabled(saving != nil || item.original == nil)
							if mine {
								Button("Apagar") { confirmDelete = true }.buttonStyle(.chunky(.danger, small: true))
							}
						}
					}
					CommentsSection(path: "/api/media/\(id)/comments", comments: Binding(get: { detail?.comments ?? [] }, set: { detail?.comments = $0 }))
						.id("comentarios")
				}
				.padding(16)
				.frame(maxWidth: 640)
				.frame(maxWidth: .infinity)
				.sheet(isPresented: $editing) {
					TextEditSheet(title: "Texto da foto", initial: item.caption) { text in
						let updated: MediaItem = try await API.shared.patch("/api/media/\(id)", ["caption": text])
						detail?.item = updated
						app.feedChanged()
					}
				}
				.fullScreenCover(isPresented: $zoom) { ZoomViewer(url: item.display ?? item.medium) }
				.confirmationDialog("Apagar este arquivo para todo mundo? Não dá para desfazer.", isPresented: $confirmDelete, titleVisibility: .visible) {
					Button("Apagar", role: .destructive) { Task { await remove() } }
				}
			} else if let error {
				EmptyState(text: error, retry: { Task { await load() } }).padding(.top, 24)
			} else {
				ProgressView().tint(.sea).padding(.top, 80)
			}
		}
		.background(DottedBackground())
		.navigationTitle("")
		.navigationBarTitleDisplayMode(.inline)
		.toolbarBackground(Color.bg, for: .navigationBar)
		.task { await load() }
		.refreshable { await load() }
	}

	@ViewBuilder private func viewer(_ item: MediaItem) -> some View {
		let ratio: CGFloat = { if let w = item.width, let h = item.height, h > 0 { CGFloat(w) / CGFloat(h) } else { 1 } }()
		Group {
			if item.status != "ready" {
				ZStack {
					if let poster = item.poster { RemoteImage(url: poster, contentMode: .fit).opacity(0.5) }
					Text(item.status == "failed" ? "Não foi possível processar este arquivo. O original está salvo e pode ser baixado." : (item.isVideo ? "Processando o vídeo (alguns minutos)…" : "Processando…"))
						.font(.text(15, .bold)).foregroundStyle(.white).multilineTextAlignment(.center).padding()
				}
				.frame(maxWidth: .infinity, minHeight: 220)
				.background(Color.black)
			} else if item.isVideo, let url = item.video {
				VideoPlayer(player: AVPlayer(url: url)).aspectRatio(ratio, contentMode: .fit)
			} else {
				RemoteImage(url: item.display ?? item.medium, contentMode: .fit)
					.aspectRatio(ratio, contentMode: .fit)
					.onTapGesture { zoom = true }
					.accessibilityAddTraits(.isButton)
					.accessibilityLabel(item.caption.isEmpty ? "Foto. Toque para ampliar" : item.caption)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 4))
		.padding(EdgeInsets(top: 8, leading: 8, bottom: 22, trailing: 8))
		.background(RoundedRectangle(cornerRadius: 8).fill(Color.polaroid))
		.shadow(color: .black.opacity(0.35), radius: 10, y: 6)
		.rotationEffect(.degrees(-0.6))
		.popIn()
	}

	private func locationLabel(_ source: String?) -> String {
		switch source {
		case "exif": "Local da própria foto"
		case "device", "device-library": "Local do celular"
		case "manual": "Local marcado à mão"
		default: "Local"
		}
	}

	private func fileLine(_ i: MediaItem) -> String {
		var parts = [i.originalName, ByteCountFormatter.string(fromByteCount: Int64(i.sizeBytes), countStyle: .file)]
		if let w = i.width, let h = i.height { parts.append("\(w)×\(h)") }
		if let d = i.durationS { parts.append(String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)) }
		return parts.joined(separator: " · ")
	}

	private func load() async {
		do { detail = try await API.shared.get("/api/media/\(id)"); error = nil } catch { app.handle(error); self.error = error.localizedDescription }
	}

	private func like(_ liked: Bool) async {
		guard let me = app.me?.id, let before = detail?.likers else { return }
		detail?.likers = liked ? before + [me] : before.filter { $0 != me }
		do {
			let r: LikeResponse = try await API.shared.post("/api/likes", LikeBody(mediaId: id, liked: liked))
			detail?.likers = r.likers
			app.feedChanged()
		} catch { detail?.likers = before; app.handle(error) }
	}

	private func remove() async {
		do { try await API.shared.delete("/api/media/\(id)"); app.feedChanged(); dismiss() } catch { app.handle(error); self.error = error.localizedDescription }
	}

	/// Downloads the untouched original (HEIC/HEVC with its metadata) and adds it to the photo library.
	private func saveOriginal(_ item: MediaItem) async {
		guard let url = item.original else { return }
		saving = "Baixando…"
		defer { saving = nil }
		guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else {
			error = "Sem permissão para salvar nas Fotos. Libere em Ajustes > Viagem."
			return
		}
		do {
			let (tmp, _) = try await URLSession.shared.download(from: url)
			let file = FileManager.default.temporaryDirectory.appending(path: item.originalName)
			try? FileManager.default.removeItem(at: file)
			try FileManager.default.moveItem(at: tmp, to: file)
			try await PHPhotoLibrary.shared().performChanges {
				let req = PHAssetCreationRequest.forAsset()
				let opts = PHAssetResourceCreationOptions()
				opts.shouldMoveFile = true
				req.addResource(with: item.isVideo ? .video : .photo, fileURL: file, options: opts)
			}
			saving = "Salvo nas Fotos ✓"
			try? await Task.sleep(for: .seconds(1.5))
		} catch {
			self.error = "Não foi possível salvar: \(error.localizedDescription)"
		}
	}
}

/// Check-in page (web /c/:id): map picture, likes, note, comments, delete.
struct CheckinDetailView: View {
	let id: String
	@Environment(AppState.self) private var app
	@Environment(\.dismiss) private var dismiss
	@State private var detail: CheckinDetail?
	@State private var error: String?
	@State private var editing = false
	@State private var confirmDelete = false

	var body: some View {
		ScrollView {
			if let d = detail {
				let item = d.item
				let person = app.person(item.userId)
				let mine = item.userId == app.me?.id
				VStack(alignment: .leading, spacing: 16) {
					HStack(spacing: 10) {
						AvatarView(name: person?.name ?? "?", color: person?.tint ?? .muted, photo: person?.photo, size: 44)
						VStack(alignment: .leading, spacing: 0) {
							Text("\(person?.name ?? "Alguém") fez check-in").font(.display(19))
							Text("\(TripTime.longDay(TripTime.dayKey(item.at))), \(TripTime.time(item.at))").font(.text(14)).foregroundStyle(Color.muted)
						}
					}
					.foregroundStyle(Color.ink)
					Group {
						if let s = item.snapshot { RemoteImage(url: s) } else { Color.sea.overlay(Icon(.pin, size: 40).foregroundStyle(.white)) }
					}
					.aspectRatio(3 / 2, contentMode: .fit)
					.clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
					.overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Color.line, lineWidth: 2.5))
					.popIn()
					HStack(spacing: 2) {
						LikeButton(liked: d.likers.contains(app.me?.id ?? "")) { liked in Task { await like(liked) } }
						LikedByView(likers: d.likers)
						Spacer()
						Link(destination: URL(string: "https://www.google.com/maps/search/?api=1&query=\(item.lat),\(item.lng)")!) { Text("Google Maps") }
							.font(.text(14, .extraBold)).tint(.leaf)
					}
					.padding(.leading, -8)
					if !item.note.isEmpty {
						Text(item.note).font(.text(17)).foregroundStyle(Color.ink)
							.padding(.horizontal, 14).padding(.vertical, 10)
							.frame(maxWidth: .infinity, alignment: .leading)
							.card(padding: 0, radius: 18)
					}
					if mine {
						HStack {
							Button(item.note.isEmpty ? "Adicionar texto" : "Editar texto") { editing = true }.font(.text(15, .extraBold)).tint(.leaf)
							Spacer()
							Button("Apagar check-in") { confirmDelete = true }.buttonStyle(.chunky(.danger, small: true))
						}
					}
					CommentsSection(path: "/api/checkins/\(id)/comments", comments: Binding(get: { detail?.comments ?? [] }, set: { detail?.comments = $0 }))
				}
				.padding(16)
				.frame(maxWidth: 640)
				.frame(maxWidth: .infinity)
				.sheet(isPresented: $editing) {
					TextEditSheet(title: "Texto do check-in", initial: item.note) { text in
						let updated: CheckinItem = try await API.shared.patch("/api/checkins/\(id)", ["note": text])
						detail?.item = updated
						app.feedChanged()
					}
				}
				.confirmationDialog("Apagar este check-in? Os comentários e curtidas dele também somem.", isPresented: $confirmDelete, titleVisibility: .visible) {
					Button("Apagar", role: .destructive) { Task { await remove() } }
				}
			} else if let error {
				EmptyState(text: error, retry: { Task { await load() } }).padding(.top, 24)
			} else {
				ProgressView().tint(.sea).padding(.top, 80)
			}
		}
		.background(DottedBackground())
		.navigationTitle("")
		.navigationBarTitleDisplayMode(.inline)
		.toolbarBackground(Color.bg, for: .navigationBar)
		.task { await load() }
		.refreshable { await load() }
	}

	private func load() async {
		do { detail = try await API.shared.get("/api/checkins/\(id)"); error = nil } catch { app.handle(error); self.error = error.localizedDescription }
	}

	private func like(_ liked: Bool) async {
		guard let me = app.me?.id, let before = detail?.likers else { return }
		detail?.likers = liked ? before + [me] : before.filter { $0 != me }
		do {
			let r: LikeResponse = try await API.shared.post("/api/likes", LikeBody(checkinId: id, liked: liked))
			detail?.likers = r.likers
			app.feedChanged()
		} catch { detail?.likers = before; app.handle(error) }
	}

	private func remove() async {
		do { try await API.shared.delete("/api/checkins/\(id)"); app.feedChanged(); dismiss() } catch { app.handle(error); self.error = error.localizedDescription }
	}
}

/// Bottom sheet to edit a caption / note.
struct TextEditSheet: View {
	let title: String
	let initial: String
	let save: (String) async throws -> Void
	@Environment(\.dismiss) private var dismiss
	@State private var text = ""
	@State private var busy = false
	@State private var error: String?

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text(title).font(.display(22)).foregroundStyle(Color.ink)
			TextField("Escreva sobre este momento…", text: $text, axis: .vertical)
				.lineLimit(3...8)
				.font(.text(17))
				.foregroundStyle(Color.ink)
				.padding(12)
				.background(RoundedRectangle(cornerRadius: 16).fill(Color.surface))
				.overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.line, lineWidth: 2.5))
			if let error { Text(error).font(.text(14, .bold)).foregroundStyle(Color.danger) }
			HStack {
				Button("Cancelar") { dismiss() }.buttonStyle(.chunky(.secondary, small: true))
				Spacer()
				Button(busy ? "Salvando…" : "Salvar") {
					Task {
						busy = true
						defer { busy = false }
						do { try await save(text); dismiss() } catch { self.error = error.localizedDescription }
					}
				}
				.buttonStyle(.chunky(.sun, small: true))
				.disabled(busy)
			}
			Spacer()
		}
		.padding(20)
		.presentationDetents([.medium])
		.presentationBackground(Color.bg)
		.onAppear { text = initial }
	}
}

/// Full-screen photo with pinch-to-zoom and drag; tap to close.
struct ZoomViewer: View {
	let url: URL?
	@Environment(\.dismiss) private var dismiss
	@State private var scale: CGFloat = 1
	@State private var base: CGFloat = 1
	@State private var offset: CGSize = .zero
	@State private var baseOffset: CGSize = .zero

	var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()
			RemoteImage(url: url, contentMode: .fit)
				.scaleEffect(scale)
				.offset(offset)
				.gesture(
					MagnifyGesture()
						.onChanged { scale = max(1, min(5, base * $0.magnification)) }
						.onEnded { _ in base = scale; if scale == 1 { withAnimation(.bounce) { offset = .zero; baseOffset = .zero } } }
						.simultaneously(with: DragGesture()
							.onChanged { v in if scale > 1 { offset = CGSize(width: baseOffset.width + v.translation.width, height: baseOffset.height + v.translation.height) } }
							.onEnded { _ in baseOffset = offset })
				)
				.onTapGesture(count: 2) { withAnimation(.bounce) { if scale > 1 { scale = 1; base = 1; offset = .zero; baseOffset = .zero } else { scale = 2.5; base = 2.5 } } }
			Button { dismiss() } label: {
				Image(systemName: "xmark").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
					.frame(width: 44, height: 44).background(Circle().fill(.black.opacity(0.5)))
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
			.padding()
			.accessibilityLabel("Fechar")
		}
	}
}
