import AVKit
import SwiftUI

/// Retrospectiva: the wedding countdown, then the admin's picks played like stories (a year-in-review).
/// Admins choose the photos/videos (from the Diário's grid) and put them in order here.
struct RetroView: View {
	@Environment(AppState.self) private var app
	@State private var retro: Retro?
	@State private var error: String?
	@State private var playing = false
	@State private var editing = false

	private var started: Bool { Date() >= Wedding.at }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				BackButton()
				TitleRow(icon: .sparkle, title: "Retrospectiva")
				if !started {
					CountdownCard(big: true)
					Text("Depois do casamento, aqui aparecem os melhores momentos da viagem, escolhidos a dedo, um atrás do outro.")
						.font(.text(16)).foregroundStyle(Color.muted)
				} else if let items = retro?.items, !items.isEmpty {
					Button { playing = true } label: {
						RemoteImage(url: items[0].image)
							.aspectRatio(4 / 5, contentMode: .fit)
							.brightness(-0.25)
							.overlay {
								VStack(spacing: 8) {
									Icon(.play, size: 34).foregroundStyle(Color.onSun).frame(width: 76, height: 76).background(Circle().fill(Color.sun))
									Text("Ver a retrospectiva").font(.display(26)).foregroundStyle(.white)
									Text("\(items.count) momentos").font(.text(15)).foregroundStyle(.white)
								}
							}
							.clipShape(RoundedRectangle(cornerRadius: 22))
							.overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.sun, lineWidth: 2.5))
					}
					.buttonStyle(.plain)
				} else if retro != nil {
					EmptyState(text: "A retrospectiva está sendo preparada. Volte daqui a pouco!")
				}
				if let error { Text(error).font(.text(14, .bold)).foregroundStyle(Color.danger) }
				if app.me?.isAdmin == true, let r = retro {
					VStack(alignment: .leading, spacing: 10) {
						Text("Só para administradores").font(.display(19)).foregroundStyle(Color.ink)
						Text("\(r.items.count) \(r.items.count == 1 ? "item escolhido" : "itens escolhidos"). Para pôr fotos, use “Todas as fotos” no Diário, Selecionar e “Retrô”.")
							.font(.text(14)).foregroundStyle(Color.muted)
						HStack {
							if !r.items.isEmpty {
								Button("Ordenar") { editing = true }.buttonStyle(.chunky(.sun, small: true))
								Button("Pré-visualizar") { playing = true }.buttonStyle(.chunky(.secondary, small: true))
							}
						}
					}
					.card()
				}
			}
			.padding(16)
			.frame(maxWidth: 640)
			.frame(maxWidth: .infinity)
		}
		// pushed from a tab: keep the end of the page above the floating dock
		.contentMargins(.bottom, 104, for: .scrollContent)
		.toolbar(.hidden, for: .navigationBar)
		.background(DottedBackground())
		.task { await load() }
		.fullScreenCover(isPresented: $playing) { StoryView(items: retro?.items ?? []) }
		.sheet(isPresented: $editing, onDismiss: { Task { await load() } }) { RetroOrder(items: retro?.items ?? []) }
	}

	private func load() async {
		do { retro = try await API.shared.get("/api/retro"); error = nil } catch { app.handle(error); self.error = error.localizedDescription }
	}
}

/// "‹ Voltar" for pages pushed inside a tab (the stacks hide the navigation bar).
struct BackButton: View {
	@Environment(\.dismiss) private var dismiss
	var body: some View {
		Button { dismiss() } label: { Text("‹ Voltar") }.buttonStyle(.chunky(.secondary, small: true))
	}
}

/// Admin: drag to reorder, swipe to take out.
private struct RetroOrder: View {
	@State var items: [FeedMedia]
	@Environment(AppState.self) private var app
	@Environment(\.dismiss) private var dismiss
	@State private var busy = false

	var body: some View {
		NavigationStack {
			List {
				ForEach(items) { m in
					HStack(spacing: 10) {
						RemoteImage(url: m.thumb ?? m.image).frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 8))
						VStack(alignment: .leading) {
							Text(m.caption.isEmpty ? (m.isVideo ? "Vídeo" : "Foto") : m.caption).font(.text(15, .bold)).lineLimit(1)
							Text(app.person(m.userId)?.name ?? "").font(.text(13)).foregroundStyle(Color.muted)
						}
					}
					.listRowBackground(Color.surface)
				}
				.onMove { items.move(fromOffsets: $0, toOffset: $1) }
				.onDelete { items.remove(atOffsets: $0) }
			}
			.environment(\.editMode, .constant(.active))
			.scrollContentBackground(.hidden)
			.background(Color.bg)
			.navigationTitle("Ordem")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) { Button(busy ? "Salvando…" : "Salvar") { Task { await save() } }.disabled(busy) }
			}
		}
		.tint(.sea)
	}

	private func save() async {
		busy = true
		defer { busy = false }
		do {
			let _: OK = try await API.shared.put("/api/admin/retro", RetroBody(mediaIds: items.map(\.id)))
			dismiss()
		} catch { app.handle(error) }
	}
}

/// The Retrospectiva as stories: an opening card, the picks in order, a closing card.
/// Tap right/left to move, hold to pause; photos stay 5 s, videos play to the end.
struct StoryView: View {
	let items: [FeedMedia]
	@Environment(AppState.self) private var app
	@Environment(\.dismiss) private var dismiss
	@State private var index = 0
	@State private var progress: Double = 0
	@State private var paused = false
	@State private var player: AVPlayer?
	private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

	private var total: Int { items.count + 2 }
	private var current: FeedMedia? { index > 0 && index <= items.count ? items[index - 1] : nil }

	var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()
			Group {
				if index == 0 { intro }
				else if let m = current { slide(m) }
				else { outro }
			}
			.id(index)
			.transition(.opacity)
		}
		.overlay(alignment: .top) {
			VStack(spacing: 10) {
				HStack(spacing: 4) {
					ForEach(0..<total, id: \.self) { n in
						GeometryReader { g in
							Capsule().fill(.white.opacity(0.35))
								.overlay(alignment: .leading) { Capsule().fill(.white).frame(width: g.size.width * (n < index ? 1 : n == index ? min(1, progress) : 0)) }
						}
						.frame(height: 3)
					}
				}
				HStack {
					Spacer()
					Button { dismiss() } label: { Icon(.close, size: 20).foregroundStyle(.white).frame(width: 44, height: 44).background(Circle().fill(.black.opacity(0.35))) }
						.accessibilityLabel("Fechar")
				}
			}
			.padding(.horizontal, 10)
		}
		.contentShape(Rectangle())
		.gesture(
			DragGesture(minimumDistance: 0)
				.onChanged { _ in paused = true; player?.pause() }
				.onEnded { v in
					paused = false
					player?.play()
					if abs(v.translation.height) > 80 { return dismiss() }
					let w = UIScreen.main.bounds.width
					if abs(v.translation.width) < 10 { go(v.location.x < w / 3 ? index - 1 : index + 1) }
				}
		)
		.onReceive(tick) { _ in
			guard !paused else { return }
			if let m = current, m.isVideo, let p = player, let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 {
				progress = p.currentTime().seconds / d
				if progress >= 0.999 { go(index + 1) }
			} else {
				progress += 0.05 / 5
				if progress >= 1 { go(index + 1) }
			}
		}
		.statusBarHidden()
		.onChange(of: index, initial: true) { _, _ in setUpPlayer() }
		.onDisappear { player?.pause() }
	}

	private func go(_ n: Int) {
		if n >= total { return dismiss() }
		withAnimation(.easeOut(duration: 0.25)) { index = max(0, n) }
		progress = 0
	}

	private func setUpPlayer() {
		player?.pause()
		if let m = current, m.isVideo, let url = m.video {
			let p = AVPlayer(url: VideoCache.shared.playable(url))
			p.play()
			player = p
		} else { player = nil }
	}

	private var people: Int { Set(items.map(\.userId)).count }
	private var days: Int { Set(items.map(\.day)).count }

	private var intro: some View {
		VStack(spacing: 14) {
			Icon(.sparkle, size: 64).foregroundStyle(Color.sun)
			Text("RETROSPECTIVA").font(.text(15, .extraBold)).kerning(3).foregroundStyle(Color.sun)
			Text("Curitiba\n2026").font(.display(58)).multilineTextAlignment(.center).foregroundStyle(.white)
			Text("\(items.count) momentos · \(days) \(days == 1 ? "dia" : "dias") · \(people) \(people == 1 ? "pessoa" : "pessoas")")
				.font(.text(17, .bold)).foregroundStyle(.white)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(RadialGradient(colors: [.berry, .bg], center: .topLeading, startRadius: 10, endRadius: 600).ignoresSafeArea())
	}

	private var outro: some View {
		VStack(spacing: 14) {
			Icon(.heart, size: 64).foregroundStyle(Color.berry)
			Text("Obrigado por\nessa viagem!").font(.display(46)).multilineTextAlignment(.center).foregroundStyle(.white)
			Text("Com amor, de Curitiba.").font(.text(17)).foregroundStyle(.white)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(RadialGradient(colors: [.sunDark, .bg], center: .topTrailing, startRadius: 10, endRadius: 600).ignoresSafeArea())
	}

	private func slide(_ m: FeedMedia) -> some View {
		ZStack(alignment: .bottomLeading) {
			if m.isVideo, let player { VideoPlayer(player: player).disabled(true) }
			else { RemoteImage(url: m.image, contentMode: .fit).frame(maxWidth: .infinity, maxHeight: .infinity) }
			let p = app.person(m.userId)
			VStack(alignment: .leading, spacing: 4) {
				HStack(spacing: 8) {
					AvatarView(name: p?.name ?? "?", color: p?.tint ?? .muted, photo: p?.photo, size: 32)
					Text(p?.name ?? "Alguém").font(.display(18))
				}
				Text(TripTime.longDay(m.day)).font(.text(14))
				if !m.caption.isEmpty { Text(m.caption).font(.text(16)) }
			}
			.foregroundStyle(.white)
			.padding(18)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
		}
	}
}
