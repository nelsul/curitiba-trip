import AVFoundation
import Observation
import SwiftUI

/// Every photo and video (no check-ins), newest first: the Diário's grid ("Todas as fotos") and the reels.
/// One request to GET /api/feed/media (already only ready ones, newest first).
@MainActor @Observable
final class MediaLibrary {
	var items: [FeedMedia] = []
	var loading = false
	var error: String?

	func refresh(app: AppState) async {
		guard !loading else { return }
		loading = true
		defer { loading = false }
		do {
			let page: GridPage = try await API.shared.get("/api/feed/media")
			items = page.media
			error = nil
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}

	func filtered(day: String?, person: String?) -> [FeedMedia] {
		items.filter { (day == nil || $0.day == day) && (person == nil || $0.userId == person) }
	}
}

private struct GridPage: Decodable { let media: [FeedMedia] }

/// Full-screen reels over the Diário, starting at the post that was tapped. Only the one on screen plays.
struct ReelsScreen: View {
	let items: [FeedMedia]
	let start: String
	@Environment(AppState.self) private var app
	@Environment(\.dismiss) private var dismiss
	@State private var current: String?
	@State private var muted = false
	@State private var framing: [FeedMedia]?
	@State private var deleting: FeedMedia?
	@State private var gone: Set<String> = []

	var body: some View {
		NavigationStack {
			// every page is the whole screen (status bar and home indicator included), so paging always lands
			// exactly on one; the safe areas are passed down for the buttons and the caption
			GeometryReader { geo in
				let insets = geo.safeAreaInsets
				ScrollView(.vertical) {
					LazyVStack(spacing: 0) {
						ForEach(items.filter { !gone.contains($0.id) }) { m in
							ReelView(media: m, person: app.person(m.userId), playing: current == m.id, muted: $muted,
									 onShare: m.isVideo ? nil : { framing = [m] },
									 onDelete: m.userId == app.me?.id || app.me?.isAdmin == true ? { deleting = m } : nil,
									 safeTop: insets.top, safeBottom: insets.bottom)
								.frame(width: geo.size.width + insets.leading + insets.trailing, height: geo.size.height + insets.top + insets.bottom)
								.id(m.id)
						}
					}
					.scrollTargetLayout()
				}
				.scrollTargetBehavior(.paging)
				.scrollPosition(id: $current)
				.scrollIndicators(.hidden)
				.contentMargins(0, for: .scrollContent)
				.ignoresSafeArea()
			}
			.background(Color.black)
			.overlay(alignment: .topLeading) {
				Button { dismiss() } label: {
					Icon(.close, size: 20).foregroundStyle(.white).frame(width: 44, height: 44).glassCircle()
				}
				.padding(12)
				.accessibilityLabel("Voltar ao diário")
			}
			.toolbar(.hidden, for: .navigationBar)
			.navigationDestination(for: Route.self) { route in
				switch route {
				case .media(let id): MediaDetailView(id: id)
				case .checkin(let id): CheckinDetailView(id: id)
				}
			}
			.onAppear { if current == nil { current = start } }
			.sheet(item: Binding(get: { framing.map(FrameSelection.init) }, set: { framing = $0?.items })) { sel in FrameMakerView(items: sel.items) }
			.confirmationDialog("Apagar esta foto/vídeo para todo mundo? Não dá para desfazer.",
								isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
				Button("Apagar", role: .destructive) { Task { await remove() } }
			}
		}
		.tint(.ink)
	}

	private func remove() async {
		guard let m = deleting else { return }
		do {
			try await API.shared.delete("/api/media/\(m.id)")
			withAnimation { _ = gone.insert(m.id) }
			app.feedChanged()
			if items.allSatisfy({ gone.contains($0.id) }) { dismiss() }
		} catch {
			app.handle(error)
		}
	}
}

/// The photos picked for a frame (sheet item).
struct FrameSelection: Identifiable {
	let items: [FeedMedia]
	var id: String { items.map(\.id).joined(separator: ",") }
}

/// One full-screen page: the photo or looping video, the like/comments rail and who posted it.
struct ReelView: View {
	let media: FeedMedia
	let person: Person?
	let playing: Bool
	@Binding var muted: Bool
	/// photos: put it in a frame and share
	var onShare: (() -> Void)? = nil
	/// owner or admin
	var onDelete: (() -> Void)? = nil
	/// the page covers the whole screen in the reels: keep the buttons and text clear of the notch and home bar
	var safeTop: CGFloat = 0
	var safeBottom: CGFloat = 0
	@Environment(AppState.self) private var app
	@State private var likers: [String]?
	@State private var favs: [String]?
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
				RemoteImage(url: media.image, contentMode: .fit).pinchToZoom()
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
			// sound and delete up top, away from the actions (no deleting by accident)
			HStack(spacing: 8) {
				if media.isVideo {
					Button { muted.toggle() } label: { Icon(muted ? .mute : .sound, size: 20).frame(width: 44, height: 44).glassCircle() }
						.accessibilityLabel(muted ? "Ligar o som" : "Desligar o som")
				}
				if let onDelete {
					Button(action: onDelete) { Icon(.trash, size: 20).frame(width: 44, height: 44).glassCircle() }
						.accessibilityLabel("Apagar")
				}
			}
			.buttonStyle(.plain)
			.foregroundStyle(.white)
			.padding(12)
			.padding(.top, safeTop)
		}
		.overlay(alignment: .bottomTrailing) { rail.padding(.trailing, 10).padding(.bottom, 28 + safeBottom) }
		.overlay(alignment: .bottomLeading) { info }
		.clipped()
		.accessibilityElement(children: .contain)
		.accessibilityLabel("\(media.isVideo ? "Vídeo" : "Foto") de \(person?.name ?? "alguém")")
	}

	/// Frosted round buttons with a label under each (web Reel .glass): like, comment, star, frame, save.
	private var rail: some View {
		VStack(spacing: 12) {
			GlassAction(label: currentLikers.isEmpty ? "Curtir" : "\(currentLikers.count)", on: currentLikers.contains(app.me?.id ?? ""), onTint: .berry) {
				LikeButton(liked: currentLikers.contains(app.me?.id ?? "")) { liked in Task { await setLike(liked) } }
					.colorScheme(.dark)
			}
			GlassAction(label: media.comments > 0 ? "\(media.comments)" : "Comentar") {
				NavigationLink(value: Route.media(media.id)) { Icon(.chat, size: 24).frame(width: 46, height: 46) }
					.accessibilityLabel("Comentários")
			}
			GlassAction(label: currentFavs.count > 1 ? "\(currentFavs.count)" : "Favorito", on: currentFavs.contains(app.me?.id ?? ""), onTint: .sun) {
				FavButton(on: currentFavs.contains(app.me?.id ?? ""), tint: .white) { on in Task { await setFav(on) } }
			}
			if let onShare {
				GlassAction(label: "Moldura") {
					Button(action: onShare) { Icon(.frame, size: 24).frame(width: 46, height: 46) }
						.accessibilityLabel("Compartilhar com moldura")
				}
			}
			GlassAction(label: "Salvar") { SaveOriginalButton(media: media, color: .white, size: 24) }
		}
		.foregroundStyle(.white)
	}

	private var currentFavs: [String] { favs ?? media.favs ?? [] }

	private func setFav(_ on: Bool) async {
		guard let me = app.me?.id else { return }
		let before = currentFavs
		favs = on ? before + [me] : before.filter { $0 != me }
		do { favs = try await Favorites.set(media.id, on) } catch {
			favs = before
			app.handle(error)
		}
	}

	private var info: some View {
		VStack(alignment: .leading, spacing: 6) {
			// tapping who posted opens the details (the old "expand" button)
			NavigationLink(value: Route.media(media.id)) {
				HStack(spacing: 8) {
					AvatarView(name: person?.name ?? "?", color: person?.tint ?? .muted, photo: person?.photo, size: 36)
					Text(person?.name ?? "Alguém").font(.display(17))
					Text(TripTime.date(media.at).map(TripTime.short) ?? "").font(.text(13)).opacity(0.85)
				}
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Abrir detalhes")
			if !media.caption.isEmpty {
				Text(media.caption).font(.text(15)).lineLimit(3)
			}
		}
		.foregroundStyle(.white)
		.shadow(color: .black.opacity(0.5), radius: 3)
		.padding(.horizontal, 14)
		.padding(.top, 48)
		.padding(.bottom, 18 + safeBottom)
		.padding(.trailing, 76)
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

/// One reel action: a dark frosted circle with a thin light ring, and a label under it.
private struct GlassAction<Content: View>: View {
	let label: String
	var on = false
	var onTint: Color = .white
	@ViewBuilder let content: Content

	var body: some View {
		VStack(spacing: 3) {
			content
				.frame(width: 48, height: 48)
				.glassCircle(tint: on ? onTint : nil)
			Text(label).font(.text(11, .extraBold)).foregroundStyle(.white).shadow(color: .black.opacity(0.8), radius: 2).lineLimit(1)
		}
	}
}

extension View {
	/// Dark frosted circle with a light ring (reels buttons); `tint` colors it when the action is on.
	func glassCircle(tint: Color? = nil) -> some View {
		background {
			ZStack {
				Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
				Circle().fill((tint ?? Color(red: 0.08, green: 0.09, blue: 0.14)).opacity(tint == nil ? 0.35 : 0.3))
			}
		}
		.overlay(Circle().strokeBorder((tint ?? .white).opacity(tint == nil ? 0.22 : 0.55), lineWidth: 1.5))
		.clipShape(Circle())
		.shadow(color: .black.opacity(0.28), radius: 7, y: 4)
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
					looper = AVPlayerLooper(player: p, templateItem: AVPlayerItem(url: VideoCache.shared.playable(url)))
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
