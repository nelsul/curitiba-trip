import SwiftUI

/// The web `--bounce` curve as a spring.
extension Animation {
	static let bounce = Animation.spring(response: 0.45, dampingFraction: 0.6)
}

/// The web `pop-in` entrance (scale 0.4 → 1.08 → 1 with fade). Off when Reduce Motion is on.
struct PopIn: ViewModifier {
	var delay: Double = 0
	@State private var shown = false
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	func body(content: Content) -> some View {
		content
			.scaleEffect(shown || reduceMotion ? 1 : 0.4)
			.opacity(shown || reduceMotion ? 1 : 0)
			.onAppear { withAnimation(.bounce.delay(delay)) { shown = true } }
	}
}

extension View {
	func popIn(delay: Double = 0) -> some View { modifier(PopIn(delay: delay)) }
}

/// Plain buttons that shrink a little while pressed (cards, tiles).
struct PressScale: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.scaleEffect(configuration.isPressed ? 0.96 : 1)
			.animation(.bounce, value: configuration.isPressed)
	}
}
