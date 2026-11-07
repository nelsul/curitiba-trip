import SwiftUI

/// Top bar: plane tile + "Curitiba" + the dates stamp, with the dashed bottom edge.
struct TopBar: View {
	var body: some View {
		HStack(spacing: 8) {
			Icon(.plane, size: 18)
				.rotationEffect(.degrees(90))
				.foregroundStyle(.white)
				.frame(width: 36, height: 36)
				.background(RoundedRectangle(cornerRadius: 12).fill(Color.sea))
				.background(RoundedRectangle(cornerRadius: 12).fill(Color.seaDark).offset(y: 3))
				.rotationEffect(.degrees(-8))
			Text("Curitiba").font(.display(24, relativeTo: .title2)).foregroundStyle(Color.ink)
			Stamp(text: "11–18/11", size: 12)
			Spacer()
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 10)
		.background(Color.bg.opacity(0.92))
		.overlay(alignment: .bottom) {
			Rectangle().fill(.clear).frame(height: 2.5)
				.overlay(Line().stroke(Color.line, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6])))
		}
		.accessibilityElement(children: .combine)
		.accessibilityLabel("Viagem a Curitiba, 11 a 18 de novembro")
	}
}

private struct Line: Shape {
	func path(in rect: CGRect) -> Path {
		var p = Path()
		p.move(to: CGPoint(x: 0, y: rect.midY))
		p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
		return p
	}
}

/// Title row: a tilted sun-colored icon tile + the screen title ("Diário da viagem").
struct TitleRow: View {
	let icon: IconName
	let title: String

	var body: some View {
		HStack(spacing: 12) {
			Icon(icon, size: 26)
				.foregroundStyle(Color.onSun)
				.frame(width: 48, height: 48)
				.background(RoundedRectangle(cornerRadius: 16).fill(Color.sun))
				.background(RoundedRectangle(cornerRadius: 16).fill(Color.sunDark).offset(y: 4))
				.rotationEffect(.degrees(-6))
			Text(title).font(.display(32, relativeTo: .largeTitle)).foregroundStyle(Color.ink)
		}
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.isHeader)
	}
}

/// The wooden sign with the day ("Sexta-feira, 13 de novembro").
struct DaySign: View {
	let text: String

	var body: some View {
		Text(text)
			.font(.display(18))
			.foregroundStyle(Color.onWood)
			.shadow(color: .woodShadow, radius: 0, y: 1)
			.padding(.horizontal, 22)
			.padding(.vertical, 6)
			.background(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [.wood, .woodDark], startPoint: .top, endPoint: .bottom)))
			.overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.woodEdge, lineWidth: 2.5))
			.background(RoundedRectangle(cornerRadius: 12).fill(Color.woodShadow).offset(y: 4))
			.accessibilityAddTraits(.isHeader)
	}
}

enum Tab: String, CaseIterable, Identifiable {
	case diario, mapa, enviar, roteiro, mais
	var id: String { rawValue }
	var label: String { ["Diário", "Mapa", "Enviar", "Roteiro", "Mais"][Self.allCases.firstIndex(of: self)!] }
	var icon: IconName { [.journal, .map, .upload, .ticket, .user][Self.allCases.firstIndex(of: self)!] }
	var color: Color { [.leaf, .sea, .sun, .coral, .plum][Self.allCases.firstIndex(of: self)!] }
}

/// The floating dock with colored icon tiles; "Enviar" is the raised yellow button (same as the web).
struct Dock: View {
	@Binding var selection: Tab

	var body: some View {
		HStack(spacing: 0) {
			ForEach(Tab.allCases) { tab in
				let active = selection == tab
				Button {
					selection = tab
				} label: {
					VStack(spacing: 2) {
						if tab == .enviar {
							// Same 38 pt slot as the other tabs (so the labels line up); the raised coin floats above it.
							Color.clear
								.frame(width: 38, height: 38)
								.overlay {
									Icon(tab.icon, size: 26)
										.foregroundStyle(Color.onSun)
										.frame(width: 56, height: 56)
										// gold depth inside the coin, navy drop like the dock (no gold crescent outside the ring)
										.background(Circle().fill(Color.sun.shadow(.inner(color: .sunDark, radius: 0, y: -4))))
										.overlay(Circle().strokeBorder(Color.surface, lineWidth: 4))
										.background(Circle().fill(Color.shadow).offset(y: 4))
										.scaleEffect(active ? 1.06 : 1)
										.offset(y: -12)
								}
						} else {
							Icon(tab.icon, size: 22)
								.foregroundStyle(.white)
								.frame(width: 38, height: 38)
								.background(RoundedRectangle(cornerRadius: 14).fill(tab.color))
								.background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.18)).offset(y: 3))
								.rotationEffect(.degrees(active ? -6 : 0))
								.scaleEffect(active ? 1.08 : 1)
								.offset(y: active ? -4 : 0)
						}
						Text(tab.label).font(.text(11, .extraBold)).foregroundStyle(active ? Color.ink : Color.muted)
					}
					.frame(maxWidth: .infinity)
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel(tab.label)
				.accessibilityAddTraits(active ? .isSelected : [])
			}
		}
		.animation(.spring(response: 0.35, dampingFraction: 0.55), value: selection)
		.sensoryFeedback(.selection, trigger: selection)
		.padding(.vertical, 8)
		.frame(maxWidth: 520)
		.background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.surface))
		.overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.line, lineWidth: 2.5))
		.background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.shadow).offset(y: 5))
		.shadow(color: .black.opacity(0.12), radius: 12, y: 6)
		.padding(.horizontal, 10)
	}
}
