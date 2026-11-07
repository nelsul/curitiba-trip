import SwiftUI

/// The upload progress bar (web UploadFlight): a plane flies along a dotted route from the camera to the island;
/// on arrival a "Chegou!" stamp lands with a burst of confetti.
struct UploadFlightView: View {
	let progress: Double
	var done = false
	var failed = false

	@State private var burst = false

	private var pct: Double { max(0, min(1, done ? 1 : progress)) }

	var body: some View {
		HStack(spacing: 6) {
			end(.camera, on: false)
			GeometryReader { g in
				let w = g.size.width
				ZStack(alignment: .leading) {
					Dots().stroke(Color.line, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [0.1, 10]))
					Dots().stroke(Color.sea, style: StrokeStyle(lineWidth: 4.4, lineCap: .round, dash: [0.1, 10]))
						.frame(width: w * pct)
						.clipped()
					Icon(.plane, size: 22)
						.foregroundStyle(failed ? Color.danger : Color.sea)
						.phaseAnimator(failed || done ? [false] : [false, true]) { v, up in
							v.rotationEffect(.degrees(90 + (up ? 3 : -3))).offset(y: up ? 2 : -2)
						} animation: { _ in .easeInOut(duration: 0.6) }
						.scaleEffect(done ? 0.6 : 1)
						.opacity(done ? 0 : 1)
						.shadow(color: .black.opacity(0.15), radius: 0, y: 2)
						.position(x: w * pct, y: g.size.height / 2)
				}
				.animation(.linear(duration: 0.3), value: pct)
			}
			.frame(height: 24)
			.padding(.horizontal, 10)
			end(.island, on: done)
		}
		.frame(height: 36)
		.overlay(alignment: .topTrailing) {
			if done {
				Text("CHEGOU!")
					.font(.display(15)).tracking(1)
					.foregroundStyle(Color.coral)
					.padding(.horizontal, 8).padding(.vertical, 1)
					.background(RoundedRectangle(cornerRadius: 8).fill(Color.surface))
					.overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.coral, lineWidth: 2.5))
					.rotationEffect(.degrees(-8))
					.offset(x: -30, y: -16)
					.transition(.scale(scale: 2.2).combined(with: .opacity))
			}
		}
		.overlay(alignment: .trailing) {
			// only when it lands while on screen (not for files that arrived earlier)
			if burst { Confetti().offset(x: -14).allowsHitTesting(false) }
		}
		.animation(.bounce, value: done)
		.onChange(of: done) { _, d in if d { burst = true } }
		.accessibilityElement()
		.accessibilityLabel("Envio")
		.accessibilityValue(done ? "Enviado" : "\(Int(pct * 100))%")
	}

	private func end(_ icon: IconName, on: Bool) -> some View {
		Icon(icon, size: 16)
			.foregroundStyle(on ? Color.onLeaf : Color.muted)
			.frame(width: 28, height: 28)
			.background(Circle().fill(on ? Color.leaf : Color.surface2))
			.overlay(Circle().strokeBorder(on ? Color.leaf : Color.line, lineWidth: 2))
	}

	private struct Dots: Shape {
		func path(in r: CGRect) -> Path {
			Path { p in
				p.move(to: CGPoint(x: 2, y: r.midY))
				p.addLine(to: CGPoint(x: max(2, r.maxX - 2), y: r.midY))
			}
		}
	}
}

/// Twelve bits of paper flying out in a circle.
private struct Confetti: View {
	@State private var go = false
	private static let colors: [Color] = [.leaf, .sun, .coral, .sea, .berry]

	var body: some View {
		ZStack {
			ForEach(0..<12, id: \.self) { i in
				let angle = Angle.degrees(Double(i) / 12 * 360 + (i % 2 == 1 ? 12 : -8))
				let dist = CGFloat(34 + (i % 3) * 12)
				RoundedRectangle(cornerRadius: i % 3 == 0 ? 3 : 2)
					.fill(Self.colors[i % 5])
					.frame(width: i % 3 == 0 ? 6 : 8, height: i % 3 == 0 ? 6 : 5)
					.rotationEffect(.degrees(go ? 260 : 0))
					.offset(x: go ? cos(angle.radians) * dist : 0, y: go ? sin(angle.radians) * dist + 10 : 0)
					.opacity(go ? 0 : 1)
					.animation(.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.9), value: go)
			}
		}
		.frame(width: 0, height: 0)
		.onAppear { go = true }
	}
}
