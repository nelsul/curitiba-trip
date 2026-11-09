import SwiftUI

/// Special effect when the bride or groom liked one of my posts. Shown once: the server remembers it was seen.
struct CoupleLoveView: View {
	let likes: [CoupleLike]
	let open: (Route?) -> Void
	@Environment(AppState.self) private var app
	@State private var falling = false
	@State private var beat = false

	private var roles: Set<String> { Set(likes.map(\.role)) }
	private var who: String { roles.count > 1 ? "Os noivos" : roles.contains("noiva") ? "A noiva" : "O noivo" }
	private var likers: [Person] { Array(Set(likes.map(\.likerId))).compactMap { app.person($0) } }
	private var posts: Int { Set(likes.map { $0.mediaId ?? $0.checkinId ?? "" }).count }

	var body: some View {
		ZStack {
			RadialGradient(colors: [Color.berry.opacity(0.5), Color.bg.opacity(0.95)], center: .center, startRadius: 20, endRadius: 500).ignoresSafeArea()
			GeometryReader { g in
				ForEach(0..<26, id: \.self) { i in
					Icon(i % 4 == 0 ? .ring : .heart, size: CGFloat(16 + (i * 11) % 28))
						.foregroundStyle(i % 3 == 0 ? Color.sun : Color.berry)
						.position(x: g.size.width * CGFloat((i * 37) % 100) / 100, y: falling ? g.size.height + 60 : -40 - CGFloat((i * 13) % 200))
						.rotationEffect(.degrees(falling ? 40 : 0))
						.animation(.linear(duration: 2.6 + Double((i * 7) % 10) / 4).repeatForever(autoreverses: false).delay(Double((i * 13) % 20) / 10), value: falling)
				}
			}
			.ignoresSafeArea()
			.allowsHitTesting(false)
			VStack(spacing: 12) {
				ZStack(alignment: .topLeading) {
					RemoteImage(url: likes.first?.image)
						.frame(width: 180, height: 180)
						.clipShape(RoundedRectangle(cornerRadius: 18))
						.overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white, lineWidth: 6))
						.rotationEffect(.degrees(-4))
						.overlay(alignment: .bottomTrailing) {
							HStack(spacing: -10) { ForEach(likers) { p in AvatarView(name: p.name, color: p.tint, photo: p.photo, size: 56) } }
								.offset(x: 22, y: 18)
						}
					Icon(.heart, size: 30).foregroundStyle(.white)
						.frame(width: 56, height: 56).background(Circle().fill(Color.berry))
						.scaleEffect(beat ? 1.2 : 1)
						.offset(x: -18, y: -18)
						.animation(.easeInOut(duration: 0.5).repeatForever(), value: beat)
				}
				.padding(.top, 8)
				Text("\(who) \(roles.count > 1 ? "curtiram" : "curtiu") \(posts > 1 ? "\(posts) posts seus" : "seu post")!")
					.font(.display(24)).foregroundStyle(Color.berry).multilineTextAlignment(.center).padding(.top, 14)
				Text("\(likers.map(\.name).joined(separator: " e ")) \(likers.count > 1 ? "deixaram" : "deixou") um coração para você.")
					.font(.text(16)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
				HStack(spacing: 10) {
					Button("Fechar") { open(nil) }.buttonStyle(.chunky(.secondary, small: true))
					Button("Ver o post") {
						let l = likes.first
						open(l?.mediaId.map(Route.media) ?? l?.checkinId.map(Route.checkin))
					}
					.buttonStyle(.chunky(.sun, small: true))
				}
			}
			.padding(24)
			.frame(maxWidth: 360)
			.background(RoundedRectangle(cornerRadius: 22).fill(Color.bg))
			.overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.berry, lineWidth: 3))
			.shadow(color: Color.berry.opacity(0.6), radius: 30)
			.padding(16)
			.popIn()
		}
		.onAppear { falling = true; beat = true }
		.sensoryFeedback(.success, trigger: falling)
		.accessibilityAddTraits(.isModal)
	}
}
