import SwiftUI

/// GET /api/notifications: the last two weeks of what the group did that concerns me (texts come ready from the server).
struct NoteItem: Decodable, Identifiable, Sendable {
	let id: String
	let kind: String // post | checkin | comment | like | mention | split | paid
	let userId: String
	let text: String
	let body: String
	let at: String
	let mediaId: String?
	let checkinId: String?
	let cotinha: Bool
	let image: URL?
	let unread: Bool
}
struct NoteList: Decodable, Sendable { let items: [NoteItem]; let unread: Int }
struct UnreadCount: Decodable, Sendable { let unread: Int }

/// The bell's red count.
@MainActor @Observable
final class NotificationsBadge {
	static let shared = NotificationsBadge()
	var unread = 0

	func refresh() async {
		guard TokenStore.shared.token != nil, let r: UnreadCount = try? await API.shared.get("/api/notifications", query: ["count": "1"]) else { return }
		unread = r.unread
	}
}

/// Notificações (the bell next to "Enviar"): posts, check-ins, comments and likes on my posts, mentions and cotinhas.
struct NotificationsView: View {
	/// a post or check-in to open, or nil for the Cotinha
	let open: (Route?) -> Void
	@Environment(AppState.self) private var app
	@State private var list: NoteList?
	@State private var error: String?

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 10) {
				TitleRow(icon: .bell, title: "Notificações")
				Text("O que o grupo fez nos últimos 14 dias: posts, check-ins, comentários e curtidas nos seus posts, quando te marcam e as cotinhas.")
					.font(.text(14)).foregroundStyle(Color.muted)
				if let error, list == nil { EmptyState(text: error, retry: { Task { await load() } }) }
				if list == nil && error == nil { ProgressView().tint(.sea).frame(maxWidth: .infinity).padding() }
				ForEach(list?.items ?? []) { n in
					Button { tap(n) } label: { row(n) }.buttonStyle(.plain)
				}
				if let list, list.items.isEmpty {
					VStack(spacing: 8) {
						Icon(.bell, size: 40).foregroundStyle(Color.muted)
						Text("Nada por aqui ainda.").font(.text(16)).foregroundStyle(Color.muted)
					}
					.frame(maxWidth: .infinity).card()
				}
			}
			.padding(16)
			.frame(maxWidth: 640)
			.frame(maxWidth: .infinity)
		}
		.refreshable { await load() }
		.task { await load() }
	}

	private func load() async {
		do {
			list = try await API.shared.get("/api/notifications")
			error = nil
			// opening the page reads everything
			NotificationsBadge.shared.unread = 0
			let _: OK? = try? await API.shared.post("/api/notifications/seen", Empty())
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}

	private func tap(_ n: NoteItem) {
		if n.cotinha { return open(nil) }
		if let m = n.mediaId { open(.media(m)) } else if let c = n.checkinId { open(.checkin(c)) }
	}

	private static let icons: [String: (IconName, Color)] = [
		"post": (.camera, .sea), "checkin": (.pin, .leaf), "comment": (.chat, .sky), "like": (.heart, .berry),
		"mention": (.chat, .plum), "split": (.wallet, .sun), "paid": (.check, .leaf)
	]

	private func row(_ n: NoteItem) -> some View {
		let p = app.person(n.userId)
		let (icon, color) = Self.icons[n.kind] ?? (.bell, .sea)
		return HStack(spacing: 12) {
			AvatarView(name: p?.name ?? "?", color: p?.tint ?? .muted, photo: p?.photo, size: 44)
				.overlay(alignment: .bottomTrailing) {
					Icon(icon, size: 12).foregroundStyle(.white)
						.frame(width: 22, height: 22).background(Circle().fill(color))
						.overlay(Circle().strokeBorder(Color.surface, lineWidth: 2))
						.offset(x: 4, y: 4)
				}
			VStack(alignment: .leading, spacing: 1) {
				Text(n.text).font(.text(15, .extraBold)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
				if !n.body.isEmpty { Text(n.body).font(.text(13)).foregroundStyle(Color.ink).lineLimit(1) }
				Text(TripTime.ago(n.at)).font(.text(12)).foregroundStyle(Color.muted)
			}
			Spacer(minLength: 0)
			if let img = n.image {
				RemoteImage(url: img).frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 10))
			}
		}
		.padding(10)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(RoundedRectangle(cornerRadius: 18).fill(n.unread ? Color.sea.opacity(0.12) : Color.surface))
		.overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(n.unread ? Color.sea : Color.line, lineWidth: 2.5))
		.overlay(alignment: .topTrailing) {
			if n.unread { Circle().fill(Color.coral).frame(width: 9, height: 9).padding(10).accessibilityLabel("Nova") }
		}
		.accessibilityElement(children: .combine)
	}
}
