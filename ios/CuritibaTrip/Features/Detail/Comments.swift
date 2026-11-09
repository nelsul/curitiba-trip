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
						Text(Mentions.highlight(c.body, people: app.people)).font(.text(16)).fixedSize(horizontal: false, vertical: true)
					}
					.foregroundStyle(Color.ink)
					.padding(.horizontal, 12)
					.padding(.vertical, 8)
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(BubbleShape().fill(Color.surface))
					.overlay(BubbleShape().stroke(Color.line, lineWidth: 2.5))
					.contextMenu {
						if c.userId == app.me?.id || app.me?.isAdmin == true {
							Button(role: .destructive) { Task { await remove(c) } } label: { Label("Apagar comentário", systemImage: "trash") }
						}
					}
				}
				.popIn()
			}

			// @mentions: people matching what's typed after "@"
			let options = Mentions.suggestions(for: draft, people: app.people.filter { $0.id != app.me?.id })
			if focused && !options.isEmpty {
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 8) {
						ForEach(options) { p in
							Button { draft = Mentions.complete(draft, with: p.name) } label: {
								HStack(spacing: 6) {
									AvatarView(name: p.name, color: p.tint, photo: p.photo, size: 26)
									Text(p.name).font(.text(15, .extraBold)).foregroundStyle(Color.ink)
								}
								.padding(.leading, 4).padding(.trailing, 12).frame(minHeight: 40)
								.background(Capsule().fill(Color.surface2))
								.overlay(Capsule().strokeBorder(Color.sea, lineWidth: 2))
							}
							.buttonStyle(.plain)
							.accessibilityLabel("Marcar \(p.name)")
						}
					}
				}
				.noDockMargin()
			}
			HStack(alignment: .bottom, spacing: 8) {
				TextField("Escreva um comentário… (@ para marcar)", text: $draft, axis: .vertical)
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

/// @mentions in comments: suggestions while typing and highlighting (same rules as the web, src/lib/mentions.ts).
enum Mentions {
	static func fold(_ s: String) -> String { s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "pt_BR")) }

	/// The "@par" at the end of the text (the composer always types at the end).
	static func query(_ text: String) -> String? {
		guard let m = text.firstMatch(of: /(?:^|[^\p{L}\p{N}_])@([\p{L}\p{N}_]*(?: [\p{L}\p{N}_]*)?)$/) else { return nil }
		let q = String(m.1)
		return q.count > 30 ? nil : q
	}

	static func suggestions(for text: String, people: [Person]) -> [Person] {
		guard let q = query(text).map(fold)?.trimmingCharacters(in: .whitespaces) else { return [] }
		return Array(people.filter { p in q.isEmpty || fold(p.name).hasPrefix(q) || fold(p.name).split(separator: " ").contains { $0.hasPrefix(q) } }.prefix(6))
	}

	/// Replaces the "@par" being typed with "@Full Name ".
	static func complete(_ text: String, with name: String) -> String {
		guard let q = query(text) else { return text }
		return String(text.dropLast(q.count + 1)) + "@\(name) "
	}

	/// The comment with @Name parts in bold sea color.
	static func highlight(_ text: String, people: [Person]) -> AttributedString {
		var out = AttributedString(text)
		let names = Set(people.flatMap { [$0.name, String($0.name.split(separator: " ").first ?? "")] }).filter { !$0.isEmpty }.sorted { $0.count > $1.count }
		for name in names {
			var from = out.startIndex
			while let r = out[from...].range(of: "@\(name)", options: [.caseInsensitive, .diacriticInsensitive]) {
				if out[r].foregroundColor == nil {
					out[r].foregroundColor = .sea
					out[r].font = .text(16, .extraBold)
				}
				from = r.upperBound
			}
		}
		return out
	}
}
