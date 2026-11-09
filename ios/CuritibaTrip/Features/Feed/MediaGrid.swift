import SwiftUI

/// Every photo and video in a square grid, like the phone's gallery. In selecting mode taps pick items (in order).
struct MediaGrid: View {
	let items: [FeedMedia]
	var selecting = false
	@Binding var selected: [String]
	var max = 99
	let open: (FeedMedia) -> Void

	private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

	var body: some View {
		LazyVGrid(columns: columns, spacing: 3) {
			ForEach(items) { m in
				let n = selected.firstIndex(of: m.id)
				Button {
					if !selecting { return open(m) }
					if let n { selected.remove(at: n) } else if selected.count < max { selected.append(m.id) }
				} label: {
					Color.surface2
						.aspectRatio(1, contentMode: .fit)
						.overlay { RemoteImage(url: m.thumb ?? m.image).scaleEffect(n != nil ? 0.88 : 1).clipShape(RoundedRectangle(cornerRadius: n != nil ? 8 : 0)) }
						.clipped()
						.overlay(alignment: .bottomTrailing) {
							if m.isVideo {
								HStack(spacing: 2) {
									Icon(.play, size: 11)
									if let d = m.durationS { Text(String(format: "%d:%02d", Int(d) / 60, Int(d) % 60)) }
								}
								.font(.text(11, .extraBold)).foregroundStyle(.white)
								.padding(.horizontal, 6).padding(.vertical, 1)
								.background(Capsule().fill(.black.opacity(0.6)))
								.padding(4)
							}
						}
						.overlay(alignment: .topTrailing) {
							if selecting {
								Text(n.map { "\($0 + 1)" } ?? "")
									.font(.text(13, .extraBold)).foregroundStyle(Color.onSea)
									.frame(width: 26, height: 26)
									.background(Circle().fill(n != nil ? Color.sea : .black.opacity(0.25)))
									.overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
									.padding(6)
							}
						}
						.animation(.bounce, value: n)
				}
				.buttonStyle(.plain)
				.accessibilityLabel(m.isVideo ? "Vídeo" : (m.caption.isEmpty ? "Foto" : m.caption))
				.accessibilityAddTraits(n != nil ? .isSelected : [])
			}
		}
	}
}
