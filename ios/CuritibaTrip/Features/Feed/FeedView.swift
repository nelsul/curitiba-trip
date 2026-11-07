import SwiftUI

/// Diário: Instagram-style feed under wooden day signs, newest first (same as the web).
struct FeedView: View {
	@Environment(AppState.self) private var app
	@State private var model = FeedModel()

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 22) {
				TitleRow(icon: .journal, title: "Diário da viagem")
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.horizontal, 16)
				if let error = model.error, model.posts.isEmpty {
					EmptyState(text: error, retry: { Task { await model.refresh(app: app) } })
				} else if model.posts.isEmpty && !model.loading {
					EmptyState(text: "Nada por aqui ainda. Que tal registrar o primeiro momento?")
				}
				ForEach(Array(model.posts.enumerated()), id: \.element.id) { i, post in
					if i == 0 || model.posts[i - 1].day != post.day {
						DaySign(text: TripTime.longDay(post.day)).padding(.top, i == 0 ? 0 : 8)
					}
					Group {
						switch post {
						case .media(_, let userId, _, _, let items):
							MediaPostView(items: items, person: app.person(userId))
						case .checkin(_, let userId, _, _, let item):
							CheckinPostView(checkin: item, person: app.person(userId))
						}
					}
					.task { await model.loadMoreIfNeeded(after: post, app: app) }
				}
				if model.loading { ProgressView().tint(.sea).padding() }
			}
			.padding(.top, 12)
			.padding(.bottom, 24)
			.frame(maxWidth: 600)
			.frame(maxWidth: .infinity)
		}
		.refreshable { await model.refresh(app: app) }
		.task { if model.posts.isEmpty { await model.refresh(app: app) } }
	}
}

struct EmptyState: View {
	let text: String
	var retry: (() -> Void)? = nil

	var body: some View {
		VStack(spacing: 12) {
			Icon(.island, size: 56).foregroundStyle(Color.sea)
			Text(text).font(.text(16)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
			if let retry { Button("Tentar de novo", action: retry).buttonStyle(.chunky(.sea, small: true)) }
		}
		.frame(maxWidth: .infinity)
		.card(padding: 24)
		.padding(.horizontal, 16)
	}
}

/// Avatar + name + subtitle, shared by both post kinds.
struct PostHeader: View {
	let person: Person?
	let subtitle: String
	var trailing: AnyView? = nil

	var body: some View {
		HStack(spacing: 10) {
			AvatarView(name: person?.name ?? "?", color: person?.tint ?? .muted, photo: person?.photo, size: 40)
			VStack(alignment: .leading, spacing: 0) {
				Text(person?.name ?? "Alguém").font(.display(17)).foregroundStyle(Color.ink)
				Text(subtitle).font(.text(13)).foregroundStyle(Color.muted)
			}
			Spacer()
			trailing
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
	}
}
