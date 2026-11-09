import SwiftUI

/// A photo/video post: swipeable carousel, double-tap to like, heart, liked-by, caption, comments.
struct MediaPostView: View {
	let items: [FeedMedia]
	let person: Person?
	@Environment(AppState.self) private var app
	@Environment(\.openReel) private var openReel
	@State private var index = 0
	@State private var likers: [String: [String]] = [:]
	@State private var bigHeart = 0

	private var current: FeedMedia { items[min(index, items.count - 1)] }
	/// Same frame as the web: between 4:5 portrait and 1.91:1 landscape, from the first item.
	private var ratio: CGFloat {
		guard let w = items.first?.width, let h = items.first?.height, h > 0 else { return 1 }
		return min(1.91, max(0.8, CGFloat(w) / CGFloat(h)))
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			PostHeader(
				person: person,
				subtitle: subtitle,
				trailing: items.count > 1 ? AnyView(Text("\(index + 1)/\(items.count)").font(.text(13, .extraBold)).foregroundStyle(Color.ink).padding(.horizontal, 8).background(Capsule().fill(Color.surface2)).overlay(Capsule().strokeBorder(Color.line, lineWidth: 2))) : nil
			)
			TabView(selection: $index) {
				ForEach(Array(items.enumerated()), id: \.element.id) { i, m in
					MediaSlide(media: m).tag(i)
				}
			}
			.tabViewStyle(.page(indexDisplayMode: .never))
			.aspectRatio(ratio, contentMode: .fit)
			.background(Color.black)
			.overlay { BigHeart(trigger: bigHeart) }
			.onTapGesture(count: 2) {
				guard !current.isVideo else { return }
				bigHeart += 1
				Task { await setLike(current, true) }
			}
			// a single tap opens the reels at this photo/video (like Instagram)
			.onTapGesture { if current.status == "ready", let openReel { openReel(current.id) } }
			.overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 2.5) }
			.overlay(alignment: .bottom) { Rectangle().fill(Color.line).frame(height: 2.5) }

			HStack(spacing: 2) {
				LikeButton(liked: likersOf(current).contains(app.me?.id ?? "")) { liked in Task { await setLike(current, liked) } }
				NavigationLink(value: Route.media(current.id)) { Icon(.chat, size: 26).foregroundStyle(Color.ink).frame(width: 44, height: 44) }
					.accessibilityLabel("Comentários")
				if let openReel, current.status == "ready" {
					Button { openReel(current.id) } label: { Icon(.expand, size: 24).foregroundStyle(Color.ink).frame(width: 44, height: 44) }
						.accessibilityLabel("Abrir em tela cheia")
				} else {
					NavigationLink(value: Route.media(current.id)) { Icon(.expand, size: 24).foregroundStyle(Color.ink).frame(width: 44, height: 44) }
						.accessibilityLabel("Abrir em tela cheia")
				}
				Spacer()
				if items.count > 1 { Dots(count: items.count, index: index) }
				Spacer().frame(width: 92)
			}
			.padding(.horizontal, 6)

			VStack(alignment: .leading, spacing: 4) {
				LikedByView(likers: likersOf(current))
				if !current.caption.isEmpty {
					(Text(person?.name ?? "").font(.text(16, .extraBold)) + Text("  ") + Text(current.caption).font(.text(16)))
						.foregroundStyle(Color.ink)
				}
				if current.comments > 0 {
					NavigationLink(value: Route.media(current.id)) {
						Text(current.comments == 1 ? "Ver 1 comentário" : "Ver os \(current.comments) comentários")
							.font(.text(14, .bold)).foregroundStyle(Color.muted)
					}
				}
			}
			.padding(.horizontal, 14)
			.padding(.bottom, 14)
		}
		.background(Color.surface)
		.overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 2.5) }
		.overlay(alignment: .bottom) { Rectangle().fill(Color.line).frame(height: 2.5) }
		.popIn()
	}

	private var subtitle: String {
		let first = TripTime.time(items.first!.at), last = TripTime.time(items.last!.at)
		return items.count > 1 && first != last ? "\(first)–\(last)" : first
	}

	private func likersOf(_ m: FeedMedia) -> [String] { likers[m.id] ?? m.likers }

	private func setLike(_ m: FeedMedia, _ liked: Bool) async {
		guard let me = app.me?.id else { return }
		let before = likersOf(m)
		if liked == before.contains(me) { return }
		likers[m.id] = liked ? before + [me] : before.filter { $0 != me } // optimistic
		do {
			let r: LikeResponse = try await API.shared.post("/api/likes", LikeBody(mediaId: m.id, liked: liked))
			likers[m.id] = r.likers
		} catch {
			likers[m.id] = before
			app.handle(error)
		}
	}
}

private struct MediaSlide: View {
	let media: FeedMedia

	var body: some View {
		ZStack {
			if media.status == "preview" || media.status == "processing", media.image != nil {
				// waiting for Wi-Fi on the sender's phone (or the original is being processed): the low-res picture for now
				RemoteImage(url: media.image)
				Label { Text(media.status == "preview" ? "\(media.isVideo ? "Vídeo completo" : "Foto completa") chega quando estiver no Wi‑Fi" : "Processando o original…") } icon: { Icon(.clock, size: 13) }
					.font(.text(12, .extraBold)).foregroundStyle(.white)
					.padding(.horizontal, 10).padding(.vertical, 5)
					.background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.6)))
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
					.padding(8)
			} else if media.status != "ready" {
				Text(media.status == "failed" ? "Não foi possível processar" : media.isVideo ? "Preparando o vídeo…" : "Processando…")
					.font(.text(15, .extraBold)).foregroundStyle(.white.opacity(0.85))
			} else {
				RemoteImage(url: media.image)
			}
			if media.isVideo && media.status == "ready" {
				Icon(.play, size: 34).foregroundStyle(.white).shadow(radius: 6)
				if let d = media.durationS {
					Text(String(format: "%d:%02d", Int(d) / 60, Int(d) % 60))
						.font(.text(12, .extraBold)).foregroundStyle(.white)
						.padding(.horizontal, 8).padding(.vertical, 2)
						.background(Capsule().fill(.black.opacity(0.6)))
						.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
						.padding(10)
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.clipped()
		.accessibilityLabel(media.isVideo ? "Vídeo" : (media.caption.isEmpty ? "Foto" : media.caption))
	}
}

/// A check-in post: the map picture (or the teal banner until it exists), heart and note.
struct CheckinPostView: View {
	let checkin: FeedCheckin
	let person: Person?
	@Environment(AppState.self) private var app
	@State private var likers: [String]?

	var body: some View {
		let current = likers ?? checkin.likers
		VStack(alignment: .leading, spacing: 0) {
			PostHeader(person: person, subtitle: "fez check-in · \(TripTime.time(checkin.at))")
			Group {
				if let snapshot = checkin.snapshot {
					RemoteImage(url: snapshot)
				} else {
					ZStack {
						Color.sea
						VStack(spacing: 10) {
							Icon(.pin, size: 34).foregroundStyle(.white)
								.frame(width: 64, height: 64)
								.background(Circle().fill(person?.tint ?? .coral))
								.overlay(Circle().strokeBorder(.white, lineWidth: 4))
							Text("Ver no mapa ›").font(.text(14, .extraBold)).foregroundStyle(.white)
						}
					}
				}
			}
			.aspectRatio(3 / 2, contentMode: .fit)
			.clipped()
			.overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 2.5) }
			.overlay(alignment: .bottom) { Rectangle().fill(Color.line).frame(height: 2.5) }
			.overlay { NavigationLink(value: Route.checkin(checkin.id)) { Color.clear.contentShape(Rectangle()) }.accessibilityLabel("Abrir check-in") }
			HStack(spacing: 2) {
				LikeButton(liked: current.contains(app.me?.id ?? "")) { liked in Task { await setLike(liked) } }
				NavigationLink(value: Route.checkin(checkin.id)) { Icon(.chat, size: 26).foregroundStyle(Color.ink).frame(width: 44, height: 44) }
					.accessibilityLabel("Comentários")
				Spacer()
			}
			.padding(.horizontal, 6)
			VStack(alignment: .leading, spacing: 4) {
				LikedByView(likers: current)
				if !checkin.note.isEmpty {
					(Text(person?.name ?? "").font(.text(16, .extraBold)) + Text("  ") + Text(checkin.note).font(.text(16)))
						.foregroundStyle(Color.ink)
				}
			}
			.padding(.horizontal, 14)
			.padding(.bottom, 14)
		}
		.background(Color.surface)
		.overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 2.5) }
		.overlay(alignment: .bottom) { Rectangle().fill(Color.line).frame(height: 2.5) }
		.popIn()
	}

	private func setLike(_ liked: Bool) async {
		guard let me = app.me?.id else { return }
		let before = likers ?? checkin.likers
		likers = liked ? before + [me] : before.filter { $0 != me }
		do {
			let r: LikeResponse = try await API.shared.post("/api/likes", LikeBody(checkinId: checkin.id, liked: liked))
			likers = r.likers
		} catch {
			likers = before
			app.handle(error)
		}
	}
}

/// The heart: fills pink, pops and throws little sparks when liked (web LikeButton).
struct LikeButton: View {
	let liked: Bool
	let toggle: (Bool) -> Void
	@State private var burst = 0

	var body: some View {
		Button {
			if !liked { burst += 1 }
			toggle(!liked)
		} label: {
			ZStack {
				Image(systemName: liked ? "heart.fill" : "heart")
					.font(.system(size: 25, weight: .semibold))
					.foregroundStyle(liked ? Color.berry : Color.ink)
					.symbolEffect(.bounce, value: burst)
				Sparks(trigger: burst)
			}
			.frame(width: 44, height: 44)
		}
		.buttonStyle(.plain)
		.sensoryFeedback(.impact(weight: .medium), trigger: burst)
		.accessibilityLabel(liked ? "Descurtir" : "Curtir")
	}
}

private struct Sparks: View {
	let trigger: Int
	@State private var go = false

	var body: some View {
		ZStack {
			ForEach(0..<6, id: \.self) { i in
				Circle()
					.fill(i.isMultiple(of: 2) ? Color.berry : Color.sun)
					.frame(width: 6, height: 6)
					.offset(y: go ? -24 : 0)
					.rotationEffect(.degrees(Double(i) * 60))
					.opacity(go ? 0 : (trigger > 0 ? 1 : 0))
			}
		}
		.allowsHitTesting(false)
		.onChange(of: trigger) {
			go = false
			withAnimation(.easeOut(duration: 0.55)) { go = true }
		}
	}
}

/// The big white heart over a double-tapped photo.
private struct BigHeart: View {
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

struct Dots: View {
	let count: Int
	let index: Int

	var body: some View {
		HStack(spacing: 5) {
			ForEach(0..<count, id: \.self) { i in
				Circle().fill(i == index ? Color.sea : Color.line)
					.frame(width: 7, height: 7)
					.scaleEffect(i == index ? 1.25 : 1)
			}
		}
		.animation(.bounce, value: index)
		.accessibilityHidden(true)
	}
}

/// "Curtido por você e mais 2", with up to three tiny avatars.
struct LikedByView: View {
	let likers: [String]
	@Environment(AppState.self) private var app

	var body: some View {
		if !likers.isEmpty {
			let me = app.me?.id
			let ordered = likers.reversed().sorted { a, _ in a == me }
			let name: (String) -> String = { id in id == me ? "você" : (app.person(id)?.name ?? "alguém") }
			HStack(spacing: 8) {
				HStack(spacing: -8) {
					ForEach(ordered.prefix(3), id: \.self) { id in
						if let p = app.person(id) { AvatarView(name: p.name, color: p.tint, photo: p.photo, size: 22) }
					}
				}
				Group {
					if likers.count == 1 {
						Text("Curtido por ") + Text(name(ordered[0])).font(.text(15, .extraBold))
					} else if likers.count == 2 {
						Text("Curtido por ") + Text(name(ordered[0])).font(.text(15, .extraBold)) + Text(" e ") + Text(name(ordered[1])).font(.text(15, .extraBold))
					} else {
						Text("Curtido por ") + Text(name(ordered[0])).font(.text(15, .extraBold)) + Text(" e ") + Text("mais \(likers.count - 1)").font(.text(15, .extraBold))
					}
				}
				.font(.text(15))
				.foregroundStyle(Color.ink)
			}
		}
	}
}

extension EnvironmentValues {
	/// Opens the full-screen reels at a photo/video (set by the Diário).
	@Entry var openReel: ((String) -> Void)? = nil
}
