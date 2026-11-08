import SwiftUI

/// The web app's icon set (exported by design/build-icons.mjs into Assets.xcassets/Icons).
enum IconName: String, CaseIterable {
	case journal, map, upload, ticket, user, calendar, people, pin, camera, plane, car, island, chat, check, heart, download, play, leaf, expand, gallery, search, locate, sound, mute
}

struct Icon: View {
	let name: IconName
	var size: CGFloat = 22

	init(_ name: IconName, size: CGFloat = 22) {
		self.name = name
		self.size = size
	}

	var body: some View {
		Image("Icons/\(name.rawValue)")
			.resizable()
			.renderingMode(.template)
			.scaledToFit()
			.frame(width: size, height: size)
			.accessibilityHidden(true)
	}
}
