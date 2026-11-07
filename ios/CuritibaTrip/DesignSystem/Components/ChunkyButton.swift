import SwiftUI

/// The web `.btn`: a pill with a solid darker edge underneath that presses down when tapped.
struct ChunkyButtonStyle: ButtonStyle {
	enum Variant { case leaf, sea, sun, secondary, danger, uber }
	var variant: Variant = .leaf
	var small = false
	var fullWidth = false

	func makeBody(configuration: Configuration) -> some View {
		ChunkyLabel(configuration: configuration, variant: variant, small: small, fullWidth: fullWidth)
	}
}

private struct ChunkyLabel: View {
	let configuration: ButtonStyleConfiguration
	let variant: ChunkyButtonStyle.Variant
	let small: Bool
	let fullWidth: Bool
	@Environment(\.isEnabled) private var isEnabled

	private var colors: (fill: Color, edge: Color, ink: Color, border: Color?) {
		switch variant {
		case .leaf: (.leaf, .leafDark, .onLeaf, nil)
		case .sea: (.sea, .seaDark, .onSea, nil)
		case .sun: (.sun, .sunDark, .onSun, nil)
		case .secondary: (.surface, .shadow, .ink, .line)
		case .danger: (.surface, .shadow, .danger, .danger)
		case .uber: (Color(white: 0.1), .black, .white, nil)
		}
	}

	var body: some View {
		let pressed = configuration.isPressed && isEnabled
		let c = colors
		configuration.label
			.font(.display(small ? 15 : 17, relativeTo: .body))
			.foregroundStyle(c.ink)
			.padding(.horizontal, small ? 16 : 22)
			.frame(minHeight: small ? 38 : 46)
			.frame(maxWidth: fullWidth ? .infinity : nil)
			.background(Capsule().fill(c.fill))
			.overlay { if let b = c.border { Capsule().strokeBorder(b, lineWidth: 2.5) } }
			.background(Capsule().fill(c.edge).offset(y: pressed ? 1 : Depth.button))
			.offset(y: pressed ? Depth.press : 0)
			.opacity(isEnabled ? 1 : 0.55)
			.animation(.easeOut(duration: 0.08), value: pressed)
			.sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, new in new }
			.contentShape(Capsule())
	}
}

extension ButtonStyle where Self == ChunkyButtonStyle {
	static func chunky(_ variant: ChunkyButtonStyle.Variant = .leaf, small: Bool = false, fullWidth: Bool = false) -> ChunkyButtonStyle {
		ChunkyButtonStyle(variant: variant, small: small, fullWidth: fullWidth)
	}
}
