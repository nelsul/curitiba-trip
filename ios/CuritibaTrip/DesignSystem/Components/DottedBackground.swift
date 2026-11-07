import SwiftUI

/// The navy background with the soft polka dots used behind every screen.
struct DottedBackground: View {
	var body: some View {
		Canvas { ctx, size in
			ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.bg))
			let step: CGFloat = 28, r: CGFloat = 2
			for y in stride(from: CGFloat(0), through: size.height + step, by: step) {
				for x in stride(from: CGFloat(0), through: size.width + step, by: step) {
					ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.bgDot))
					ctx.fill(Path(ellipseIn: CGRect(x: x + step / 2 - r, y: y + step / 2 - r, width: r * 2, height: r * 2)), with: .color(.bgDot))
				}
			}
		}
		.ignoresSafeArea()
		.accessibilityHidden(true)
	}
}
