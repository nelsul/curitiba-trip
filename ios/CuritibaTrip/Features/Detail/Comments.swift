import SwiftUI

/// Speech-bubble comments + composer, for a photo/video or a check-in (same as the web Comments component).
struct CommentsSection: View {
	/// e.g. "/api/media/<id>/comments"
	let path: String
	@Binding var comments: [Comment]
	@Environment(AppState.self) private var app
	@State private var draft = ""
	@State private var sending = false
	@State private var error: String?
	@FocusState private var focused: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 8) {
				Icon(.chat, size: 22)
				Text("Comentários").font(.display(22))
			}
			.foregroundStyle(Color.ink)
			.accessibilityAddTraits(.isHeader)

			if comments.isEmpty { Text("Ninguém comentou ainda.").font(.text(15)).foregroundStyle(Color.muted) }
			ForEach(comments) { c in
				HStack(alignment: .top, spacing: 10) {
					AvatarView(name: c.name, color: c.tint, photo: c.photo, size: 34)
					VStack(alignment: .leading, spacing: 2) {
						HStack(spacing: 6) {
							Text(c.name).font(.display(15))
							Text(TripTime.ago(c.at)).font(.text(12)).foregroundStyle(Color.muted)
						}
						Text(c.body).font(.text(16)).fixedSize(horizontal: false, vertical: true)
					}
					.foregroundStyle(Color.ink)
					.padding(.horizontal, 12)
					.padding(.vertical, 8)
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(BubbleShape().fill(Color.surface))
					.overlay(BubbleShape().stroke(Color.line, lineWidth: 2.5))
					.contextMenu {
						if c.userId == app.me?.id {
							Button(role: .destructive) { Task { await remove(c) } } label: { Label("Apagar comentário", systemImage: "trash") }
						}
					}
				}
				.popIn()
			}

			HStack(alignment: .bottom, spacing: 8) {
				TextField("Escreva um comentário…", text: $draft, axis: .vertical)
					.lineLimit(1...5)
					.font(.text(16))
					.foregroundStyle(Color.ink)
					.focused($focused)
					.padding(.horizontal, 14)
					.padding(.vertical, 10)
					.background(RoundedRectangle(cornerRadius: 16).fill(Color.surface))
					.overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(focused ? Color.sea : Color.line, lineWidth: 2.5))
					.contentShape(Rectangle())
					.onTapGesture { focused = true } // the whole box focuses, not just the text line
				Button { Task { await send() } } label: { Text(sending ? "…" : "Comentar") }
					.buttonStyle(.chunky(.sea, small: true))
					.disabled(sending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
			}
			if let error { Text(error).font(.text(14, .bold)).foregroundStyle(Color.danger) }
		}
	}

	private func send() async {
		sending = true
		defer { sending = false }
		do {
			let c: Comment = try await API.shared.post(path, ["body": draft])
			withAnimation(.bounce) { comments.append(c) }
			draft = ""
			focused = false
			error = nil
			app.feedChanged()
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}

	private func remove(_ c: Comment) async {
		do {
			try await API.shared.delete("/api/comments/\(c.id)")
			withAnimation { comments.removeAll { $0.id == c.id } }
			app.feedChanged()
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}
}

/// Rounded speech bubble with a little tail on the left (web `.say`).
struct BubbleShape: Shape {
	func path(in r: CGRect) -> Path {
		var p = Path(roundedRect: r, cornerRadius: 18, style: .continuous)
		p.move(to: CGPoint(x: r.minX + 1, y: r.minY + 12))
		p.addLine(to: CGPoint(x: r.minX - 8, y: r.minY + 19))
		p.addLine(to: CGPoint(x: r.minX + 1, y: r.minY + 26))
		return p
	}
}
