import AVFoundation
import Observation
import SwiftUI

/// Every photo and video (no check-ins), newest first, paged through GET /api/feed.
@MainActor @Observable
final class GaleriaModel {
	var items: [FeedMedia] = []
	var loading = false
	var error: String?
	private var cursor: String?
	private var reachedEnd = false

	func refresh(app: AppState) async {
		cursor = nil
		reachedEnd = false
		await load(app: app, replace: true)
	}

	/// Loads the next page a few items before the end, so swiping never waits.
	func loadMoreIfNeeded(near item: FeedMedia, app: AppState) async {
		guard !reachedEnd, !loading, let i = items.firstIndex(where: { $0.id == item.id }), i >= items.count - 4 else { return }
		await load(app: app, replace: false)
	}

	private func load(app: AppState, replace: Bool) async {
		loading = true
		defer { loading = false }
		do {
			var found: [FeedMedia] = []
			// a page may be all check-ins: keep going until there's something to show
			repeat {
				let page: FeedPage = try await API.shared.get("/api/feed", query: ["limit": "30", "before": replace && found.isEmpty && cursor == nil ? nil : cursor])
				for post in page.posts {
					if case .media(_, _, _, _, let media) = post {
						// carousels are oldest → newest inside; the Galeria is newest first
						found += media.reversed().filter { $0.status == "ready" && ($0.image != nil || $0.video != nil) }
					}
				}
				cursor = page.nextCursor
				reachedEnd = page.nextCursor == nil
			} while found.isEmpty && !reachedEnd
			items = replace ? found : items + found.filter { f in !items.contains { $0.id == f.id } }
			error = nil
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}
}

/// Galeria: full-screen photos and videos, swiping up like Reels. Only the one on screen plays.
struct GaleriaView: View {
	@Environment(AppState.self) private var app
	@State private var model = GaleriaModel()
	@State private var current: String?
	@State private var muted = false
	/// False while another page (a detail) covers the Galeria or the tab is gone.
	@State private var onScreen = false

	var body: some View {
		GeometryReader { geo in
			ScrollView(.vertical) {
				LazyVStack(spacing: 0) {
					ForEach(model.items) { m in
						ReelView(media: m, person: app.person(m.userId), playing: onScreen && current == m.id, muted: $muted)
							.frame(width: geo.size.width, height: geo.size.height)
							.task { await model.loadMoreIfNeeded(near: m, app: app) }
					}
				}
				.scrollTargetLayout()
			}
			.scrollTargetBehavior(.paging)
			.scrollPosition(id: $current)
			.scrollIndicators(.hidden)
			.contentMargins(.bottom, 0, for: .scrollContent)
			.overlay {
				if model.items.isEmpty {
					if model.loading { ProgressView().tint(.sea) }
					else if let e = model.error { EmptyState(text: e, retry: { Task { await model.refresh(app: app) } }) }
					else { EmptyState(text: "Nenhuma foto ou vídeo ainda.") }
				}
			}
		}
		.background(Color.black)
		// the floating dock covers the bottom: pages end above it
		.padding(.bottom, 92)
		.background(Color.bg)
		.refreshable { await model.refresh(app: app) }
		.task {
			if model.items.isEmpty { await model.refresh(app: app) }
			if current == nil { current = model.items.first?.id }
		}
		.onAppear { onScreen = true }
		.onDisappear { onScreen = false }
		.onChange(of: app.feedVersion) { Task { await model.refresh(app: app) } }
	}
}

/// One full-screen page: the photo or looping video, the like/comments rail and who posted it.
private struct ReelView: View {
	let media: FeedMedia
	let person: Person?
	let playing: Bool
	@Binding var muted: Bool
	@Environment(AppState.self) private var app
	@State private var likers: [String]?
	@State private var bigHeart = 0
	@State private var paused = false

	private var currentLikers: [String] { likers ?? media.likers }

	var body: some View {
		ZStack {
			Color.black
			if media.isVideo, let url = media.video {
				LoopingVideo(url: url, playing: playing && !paused, muted: muted)
				// the poster until the video has frames
				if !playing { RemoteImage(url: media.image, contentMode: .fit) }
				if paused || !playing {
					Icon(.play, size: 56).foregroundStyle(.white.opacity(0.85)).shadow(radius: 8).allowsHitTesting(false)
				}
			} else {
				RemoteImage(url: media.image, contentMode: .fit)
			}
			BigHeartView(trigger: bigHeart)
		}
		.contentShape(Rectangle())
		.onTapGesture(count: 2) {
			bigHeart += 1
			Task { await setLike(true) }
		}
		.onTapGesture { if media.isVideo { paused.toggle() } }
		.onChange(of: playing) { _, on in if on { paused = false } }
		.overlay(alignment: .topTrailing) {
			if media.isVideo {
				Button { muted.toggle() } label: {
					Icon(muted ? .mute : .sound, size: 20).foregroundStyle(.white)
						.frame(width: 44, height: 44).background(Circle().fill(.black.opacity(0.45)))
				}
				.buttonStyle(.plain)
				.padding(12)
				.accessibilityLabel(muted ? "Ligar o som" : "Desligar o som")
			}
		}
		.overlay(alignment: .bottomTrailing) { rail.padding(.trailing, 6).padding(.bottom, 18) }
		.overlay(alignment: .bottomLeading) { info }
		.clipped()
		.accessibilityElement(children: .contain)
		.accessibilityLabel("\(media.isVideo ? "Vídeo" : "Foto") de \(person?.name ?? "alguém")")
	}

	private var rail: some View {
		VStack(spacing: 4) {
			LikeButton(liked: currentLikers.contains(app.me?.id ?? "")) { liked in Task { await setLike(liked) } }
				.colorScheme(.dark)
			if !currentLikers.isEmpty { count(currentLikers.count) }
			NavigationLink(value: Route.media(media.id)) { Icon(.chat, size: 28).frame(width: 44, height: 44) }
				.accessibilityLabel("Comentários")
				.padding(.top, 6)
			if media.comments > 0 { count(media.comments) }
			NavigationLink(value: Route.media(media.id)) { Icon(.expand, size: 26).frame(width: 44, height: 44) }
				.accessibilityLabel("Abrir detalhes")
				.padding(.top, 6)
		}
		.foregroundStyle(.white)
		.shadow(color: .black.opacity(0.6), radius: 3)
	}

	private func count(_ n: Int) -> some View {
		Text("\(n)").font(.text(13, .extraBold)).foregroundStyle(.white).padding(.top, -6)
	}

	private var info: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(spacing: 8) {
				AvatarView(name: person?.name ?? "?", color: person?.tint ?? .muted, photo: person?.photo, size: 36)
				Text(person?.name ?? "Alguém").font(.display(17))
				Text(TripTime.date(media.at).map(TripTime.short) ?? "").font(.text(13)).opacity(0.85)
			}
			if !media.caption.isEmpty {
				Text(media.caption).font(.text(15)).lineLimit(3)
			}
		}
		.foregroundStyle(.white)
		.shadow(color: .black.opacity(0.5), radius: 3)
		.padding(.horizontal, 14)
		.padding(.top, 48)
		.padding(.bottom, 18)
		.padding(.trailing, 64)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false))
	}

	private func setLike(_ liked: Bool) async {
		guard let me = app.me?.id else { return }
		let before = currentLikers
		if liked == before.contains(me) { return }
		likers = liked ? before + [me] : before.filter { $0 != me }
		do {
			let r: LikeResponse = try await API.shared.post("/api/likes", LikeBody(mediaId: media.id, liked: liked))
			likers = r.likers
		} catch {
			likers = before
			app.handle(error)
		}
	}
}

/// A muted-or-not looping video that only has a player while it's the page on screen.
private struct LoopingVideo: UIViewRepresentable {
	let url: URL
	let playing: Bool
	let muted: Bool

	func makeUIView(context: Context) -> PlayerView { PlayerView() }

	func updateUIView(_ view: PlayerView, context: Context) {
		view.update(url: url, playing: playing, muted: muted)
	}

	static func dismantleUIView(_ view: PlayerView, coordinator: ()) { view.release() }

	final class PlayerView: UIView {
		override class var layerClass: AnyClass { AVPlayerLayer.self }
		private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
		private var player: AVQueuePlayer?
		private var looper: AVPlayerLooper?

		func update(url: URL, playing: Bool, muted: Bool) {
			playerLayer.videoGravity = .resizeAspect
			if playing {
				if player == nil {
					let p = AVQueuePlayer()
					looper = AVPlayerLooper(player: p, templateItem: AVPlayerItem(url: url))
					playerLayer.player = p
					player = p
					// play sound even with the silent switch on, like other video apps
					try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
				}
				player?.isMuted = muted
				player?.play()
			} else {
				player?.pause()
			}
		}

		func release() {
			player?.pause()
			looper = nil
			player = nil
			playerLayer.player = nil
		}
	}
}

/// The big white heart over a double-tapped page.
private struct BigHeartView: View {
	let trigger: Int
	@State private var phase: CGFloat = 0

	var body: some View {
		Image(systemName: "heart.fill")
			.font(.system(size: 96))
			.foregroundStyle(.white)
			.shadow(color: .black.opacity(0.4), radius: 12)
			.scaleEffect(phase == 0 ? 0.1 : (phase < 1 ? 1.15 : 1.0))
			.opacity(phase == 0 || phase >= 2 ? 0 : 1)
			.offset(y: phase >= 2 ? -30 : 0)
			.allowsHitTesting(false)
			.onChange(of: trigger) {
				phase = 0
				withAnimation(.bounce) { phase = 0.5 }
				withAnimation(.easeIn(duration: 0.3).delay(0.6)) { phase = 2 }
			}
	}
}
