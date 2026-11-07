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
				FeedFilters(model: model)
				if let error = model.error, model.posts.isEmpty {
					EmptyState(text: error, retry: { Task { await model.refresh(app: app) } })
				} else if model.posts.isEmpty && !model.loading {
					EmptyState(text: model.day != nil || model.person != nil ? "Nada com esses filtros." : "Nada por aqui ainda. Que tal registrar o primeiro momento?")
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
		.onChange(of: app.feedVersion) { Task { await model.refresh(app: app) } }
		.onChange(of: model.day) { Task { await model.refresh(app: app) } }
		.onChange(of: model.person) { Task { await model.refresh(app: app) } }
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

/// Day and person chips under the title (web Filters): "Todos os dias" + one dashed chip per day, "Todo mundo" + one chip per person.
private struct FeedFilters: View {
	@Bindable var model: FeedModel
	@Environment(AppState.self) private var app

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 8) {
					Chip(selected: model.day == nil, action: { model.day = nil }) {
						Label { Text("Todos os dias") } icon: { Icon(.calendar, size: 16) }
					}
					ForEach(model.days, id: \.self) { d in
						let wedding = d == TripTime.weddingDay
						Chip(selected: model.day == d, dashed: true, tint: wedding ? .berry : nil, action: { model.day = model.day == d ? nil : d }) {
							HStack(spacing: 5) {
								Text(String(d.suffix(2))).font(.text(15, .extraBold))
								Text(TripTime.shortWeekday(d)).font(.text(14, .bold))
								if wedding { Circle().frame(width: 7, height: 7) }
							}
						}
						.accessibilityLabel(TripTime.longDay(d))
					}
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 4)
			}
			.noDockMargin()
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 8) {
					Chip(selected: model.person == nil, action: { model.person = nil }) {
						Label { Text("Todo mundo") } icon: { Icon(.people, size: 16) }
					}
					ForEach(app.people) { p in
						Chip(selected: model.person == p.id, action: { model.person = model.person == p.id ? nil : p.id }) {
							HStack(spacing: 6) {
								AvatarView(name: p.name, color: p.tint, photo: p.photo, size: 24)
								Text(p.name)
							}
							.padding(.leading, -10)
						}
					}
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 4)
			}
			.noDockMargin()
		}
		.animation(.bounce, value: model.day)
		.animation(.bounce, value: model.person)
	}
}
