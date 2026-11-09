import NukeUI
import SwiftUI

/// Cached remote image (memory + disk, via Nuke), keyed by the file path so it survives the daily new signature (see MediaCache).
struct RemoteImage: View {
	let url: URL?
	var contentMode: ContentMode = .fill

	var body: some View {
		LazyImage(request: MediaCache.imageRequest(url)) { state in
			if let image = state.image {
				image.resizable().aspectRatio(contentMode: contentMode)
			} else {
				Rectangle().fill(Color.track)
			}
		}
	}
}
