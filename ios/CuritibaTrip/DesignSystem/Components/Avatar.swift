import SwiftUI

/// Profile photo in a circle with a ring in the person's color, or their initials on that color.
struct AvatarView: View {
	let name: String
	let color: Color
	var photo: URL? = nil
	var size: CGFloat = 32

	var body: some View {
		Group {
			if let photo {
				RemoteImage(url: photo)
					.frame(width: size, height: size)
					.clipShape(Circle())
					.overlay(Circle().strokeBorder(color, lineWidth: max(2, size * 0.06)))
			} else {
				Text(initials(name))
					.font(.display(size * 0.38, relativeTo: .caption))
					.foregroundStyle(.white)
					.frame(width: size, height: size)
					.background(Circle().fill(color))
					.overlay(Circle().strokeBorder(.white, lineWidth: max(2, size * 0.06)))
			}
		}
		.shadow(color: .black.opacity(0.15), radius: 0, y: 2)
		.accessibilityHidden(true)
	}
}

func initials(_ name: String) -> String {
	name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined().uppercased()
}

extension Color {
	/// "#2F5A40" → Color (people's colors come from the API).
	init(hex: String) {
		let v = Int(hex.dropFirst(), radix: 16) ?? 0x2F5A40
		self.init(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
	}
}
