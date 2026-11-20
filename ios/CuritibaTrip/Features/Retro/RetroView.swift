import AVKit
import SwiftUI

/// Retrospectiva: every photo/video someone starred, oldest first, in a grid by day like "Todas as fotos" (web /retro).
/// Tapping one opens the reels; the cover plays it all like stories (a year-in-review).
struct RetroView: View {
	@Environment(AppState.self) private var app
	@State private var retro: Retro?
	@State private var error: String?
	@State private var playing = false
	@State private var reel: ReelStart?

	/// day → starred items, oldest first
	private var days: [(day: String, items: [FeedMedia])] {
		var out: [(day: String, items: [FeedMedia])] = []
		for m in retro?.items ?? [] {
			if out.last?.day == m.day { out[out.count - 1].items.append(m) } else { out.append((m.day, [m])) }
		}
		return out
	}
	/// the cover: the most starred moment (the oldest of them on a tie)
	private var cover: FeedMedia? {
		(retro?.items ?? []).reduce(nil) { best, m in (m.favs?.count ?? 0) > (best?.favs?.count ?? -1) ? m : best }
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				BackButton()
				TitleRow(icon: .sparkle, title: "Retrospectiva")
				(Text("Os favoritos de todo mundo, na ordem em que aconteceram. Toque na ") + Text(Image(systemName: "star.fill")).foregroundColor(.sun) + Text(" de uma foto ou vídeo no diário para pôr aqui."))
					.font(.text(15)).foregroundStyle(Color.muted)
				if let items = retro?.items, !items.isEmpty {
					Button { playing = true } label: {
						RemoteImage(url: cover?.image)
							.aspectRatio(16 / 10, contentMode: .fit)
							.brightness(-0.25)
							.overlay {
								VStack(spacing: 8) {
									Icon(.play, size: 30).foregroundStyle(Color.onSun).frame(width: 66, height: 66).background(Circle().fill(Color.sun))
									Text("Ver a retrospectiva").font(.display(24)).foregroundStyle(.white)
									Text("\(items.count) \(items.count == 1 ? "momento" : "momentos")").font(.text(15)).foregroundStyle(.white)
								}
							}
							.clipShape(RoundedRectangle(cornerRadius: 22))
							.overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.sun, lineWidth: 2.5))
					}
					.buttonStyle(.plain)
					ForEach(days, id: \.day) { d in
						VStack(alignment: .leading, spacing: 8) {
							Text(TripTime.longDay(d.day)).font(.display(18)).foregroundStyle(Color.ink)
							// edge to edge, like "Todas as fotos"
							MediaGrid(items: d.items, selected: .constant([])) { m in reel = ReelStart(id: m.id) }
								.padding(.horizontal, -16)
						}
					}
				} else if retro != nil {
					EmptyState(text: "Nenhum favorito ainda. No diário ou na tela cheia, toque na estrela das fotos e vídeos que merecem entrar aqui.")
				}
				if let error { Text(error).font(.text(14, .bold)).foregroundStyle(Color.danger) }
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
		.refreshable { await load() }
		.onChange(of: app.feedVersion) { Task { await load() } }
		.fullScreenCover(isPresented: $playing) { StoryView(items: retro?.items ?? []) }
		.fullScreenCover(item: $reel) { r in ReelsScreen(items: retro?.items ?? [], start: r.id) }
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
	/// "Ver detalhes": the item's page over the stories, which wait meanwhile
	@State private var details: DetailsOf?
	struct DetailsOf: Identifiable { let id: String }
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
			guard !paused, details == nil else { return }
			if let m = current, m.isVideo, let p = player, let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 {
				progress = p.currentTime().seconds / d
				if progress >= 0.999 { go(index + 1) }
			} else {
				progress += 0.05 / 5
				if progress >= 1 { go(index + 1) }
			}
		}
		.statusBarHidden()
		.sheet(item: $details) { d in
			NavigationStack {
				MediaDetailView(id: d.id)
					.navigationDestination(for: Route.self) { route in
						switch route {
						case .media(let id): MediaDetailView(id: id)
						case .checkin(let id): CheckinDetailView(id: id)
						}
					}
			}
			// back to the stories
			.overlay(alignment: .topTrailing) {
				Button { details = nil } label: {
					Icon(.close, size: 18).foregroundStyle(Color.ink).frame(width: 40, height: 40)
						.background(Circle().fill(Color.surface)).overlay(Circle().strokeBorder(Color.line, lineWidth: 2))
				}
				.padding(12)
				.accessibilityLabel("Voltar à retrospectiva")
			}
			.presentationDragIndicator(.visible)
		}
		.onChange(of: details == nil) { _, closed in if closed { player?.play() } else { player?.pause() } }
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
				if let favs = m.favs, !favs.isEmpty {
					Label("favorito de \(favs.compactMap { app.person($0)?.name }.joined(separator: ", "))", systemImage: "star.fill")
						.font(.text(13, .extraBold)).foregroundStyle(Color.sun)
				}
				if !m.caption.isEmpty { Text(m.caption).font(.text(16)) }
				// a high-priority tap: the stories' own tap (next/previous) must not also fire
				Label("Ver detalhes", systemImage: "info.circle")
					.font(.text(15, .extraBold)).foregroundStyle(.white)
					.padding(.horizontal, 14).padding(.vertical, 8)
					.background(Capsule().fill(.white.opacity(0.16)))
					.overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1.5))
					.contentShape(Capsule())
					.highPriorityGesture(TapGesture().onEnded { details = DetailsOf(id: m.id) })
					.accessibilityAddTraits(.isButton)
					.padding(.top, 6)
			}
			.foregroundStyle(.white)
			.padding(18)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
		}
	}
}
