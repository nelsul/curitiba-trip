import SwiftUI

/// The web `.card`: surface, 2.5 pt border and a solid shadow edge underneath.
struct CardStyle: ViewModifier {
	var padding: CGFloat = 16
	var radius: CGFloat = Radius.card

	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
		content
			.padding(padding)
			.background(shape.fill(Color.surface))
			.overlay(shape.strokeBorder(Color.line, lineWidth: 2.5))
			.background(shape.fill(Color.shadow).offset(y: Depth.card))
	}
}

extension View {
	func card(padding: CGFloat = 16, radius: CGFloat = Radius.card) -> some View {
		modifier(CardStyle(padding: padding, radius: radius))
	}
}

/// Pill chip (filters). `dashed` = the passport-stamp day chips.
struct Chip<Label: View>: View {
	var selected = false
	var dashed = false
	var tint: Color? = nil
	let action: () -> Void
	@ViewBuilder let label: () -> Label

	var body: some View {
		Button(action: action) {
			label()
				.font(.text(15, .extraBold))
				.foregroundStyle(selected ? Color.onSea : (tint ?? .ink))
				.padding(.horizontal, 16)
				.frame(minHeight: 38)
				.background(Capsule().fill(selected ? Color.sea : Color.surface))
				.overlay(
					Capsule().strokeBorder(
						selected ? Color.sea : (tint ?? .line),
						style: StrokeStyle(lineWidth: 2.5, dash: dashed && !selected ? [6, 4] : [])
					)
				)
				.background(Capsule().fill(selected ? Color.seaDark : Color.shadow).offset(y: Depth.chip))
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(selected ? .isSelected : [])
	}
}

/// A rotated, dashed "passport stamp" label (e.g. 11–18/11).
struct Stamp: View {
	let text: String
	var color: Color = .coral
	var size: CGFloat = 13

	var body: some View {
		Text(text)
			.font(.display(size))
			.foregroundStyle(color)
			.padding(.horizontal, 7)
			.padding(.vertical, 1)
			.overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(color, style: StrokeStyle(lineWidth: 2.5, dash: [5, 3])))
			.rotationEffect(.degrees(-4))
	}
}
