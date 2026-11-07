import NukeUI
import SwiftUI

/// Cached remote image (memory + disk, via Nuke). R2 URLs stay the same for a whole day, so cache hits are common.
struct RemoteImage: View {
	let url: URL?
	var contentMode: ContentMode = .fill

	var body: some View {
		LazyImage(url: url) { state in
			if let image = state.image {
				image.resizable().aspectRatio(contentMode: contentMode)
			} else {
				Rectangle().fill(Color.track)
			}
		}
	}
}
