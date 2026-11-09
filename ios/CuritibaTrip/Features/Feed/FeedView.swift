import SwiftUI

/// Diário: Instagram-style feed under wooden day signs, newest first (same as the web).
struct FeedView: View {
	@Environment(AppState.self) private var app
	@State private var model = FeedModel()
	/// every photo/video: the grid and the reels
	@State private var library = MediaLibrary()
	@State private var grid = false
	@State private var reel: ReelStart?
	@State private var selecting = false
	@State private var selected: [String] = []
	@State private var framing: FrameSelection?
	@State private var toast: String?

	private var media: [FeedMedia] { library.filtered(day: model.day, person: model.person) }

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 22) {
				TitleRow(icon: .journal, title: "Diário da viagem")
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.horizontal, 16)
				NavigationLink { RetroView() } label: { CountdownCard() }
					.buttonStyle(.plain)
					.padding(.horizontal, 16)
				ModeSwitch(grid: $grid).padding(.horizontal, 16)
				FeedFilters(model: model)
				if grid { gridContent } else { posts }
				if model.loading || (grid && library.loading && library.items.isEmpty) { ProgressView().tint(.sea).padding() }
			}
			.padding(.top, 12)
			.padding(.bottom, selecting ? 120 : 24)
			.frame(maxWidth: 600)
			.frame(maxWidth: .infinity)
		}
		.environment(\.openReel) { id in
			Task {
				if !library.items.contains(where: { $0.id == id }) { await library.refresh(app: app) }
				reel = ReelStart(id: id)
			}
		}
		.overlay(alignment: .bottom) { selectionBar }
		.overlay(alignment: .bottom) {
			if let toast {
				Text(toast).font(.text(14, .extraBold)).foregroundStyle(Color.onLeaf)
					.padding(.horizontal, 16).padding(.vertical, 8).background(Capsule().fill(Color.leaf))
					.padding(.bottom, 180).transition(.opacity)
			}
		}
		.fullScreenCover(item: $reel) { r in ReelsScreen(items: media.contains { $0.id == r.id } ? media : library.items, start: r.id) }
		.sheet(item: $framing) { f in FrameMakerView(items: f.items) }
		.refreshable {
			await model.refresh(app: app)
			if grid { await library.refresh(app: app) }
		}
		.task { if model.posts.isEmpty { await model.refresh(app: app) } }
		.onChange(of: grid) { _, on in
			selecting = false
			selected = []
			if on && library.items.isEmpty { Task { await library.refresh(app: app) } }
		}
		.onChange(of: app.feedVersion) { Task {
			await model.refresh(app: app)
			if !library.items.isEmpty { await library.refresh(app: app) }
		} }
		.onChange(of: model.day) { Task { await model.refresh(app: app) } }
		.onChange(of: model.person) { Task { await model.refresh(app: app) } }
	}

	@ViewBuilder private var gridContent: some View {
		HStack {
			Text("\(media.count) \(media.count == 1 ? "item" : "itens")").font(.text(14)).foregroundStyle(Color.muted)
			Spacer()
			Button(selecting ? "Cancelar" : "Selecionar") { selecting.toggle(); selected = [] }
				.buttonStyle(.chunky(selecting ? .secondary : .leaf, small: true))
		}
		.padding(.horizontal, 16)
		if selecting {
			Text("Escolha até \(Frames.max) fotos para juntar numa imagem com moldura.")
				.font(.text(14)).foregroundStyle(Color.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
		}
		if let e = library.error, library.items.isEmpty {
			EmptyState(text: e, retry: { Task { await library.refresh(app: app) } })
		} else if media.isEmpty && !library.loading {
			EmptyState(text: "Nenhuma foto ou vídeo com esses filtros.")
		}
		MediaGrid(items: selecting && app.me?.isAdmin != true ? media.filter { !$0.isVideo } : media, selecting: selecting, selected: $selected,
				  max: app.me?.isAdmin == true ? 300 : Frames.max) { m in reel = ReelStart(id: m.id) }
	}

	@ViewBuilder private var selectionBar: some View {
		if selecting && !selected.isEmpty {
			let picked = selected.compactMap { id in library.items.first { $0.id == id } }
			HStack(spacing: 8) {
				Text("\(selected.count) \(selected.count == 1 ? "escolhida" : "escolhidas")").font(.text(16, .extraBold)).foregroundStyle(Color.ink)
				Spacer()
				if app.me?.isAdmin == true {
					Button { Task { await addToRetro() } } label: { Label { Text("Retrô") } icon: { Icon(.sparkle, size: 16) } }
						.buttonStyle(.chunky(.secondary, small: true))
				}
				Button { framing = FrameSelection(items: picked) } label: { Label { Text("Moldura") } icon: { Icon(.frame, size: 16) } }
					.buttonStyle(.chunky(.sun, small: true))
					.disabled(picked.count > Frames.max || picked.contains { $0.isVideo })
			}
			.padding(12)
			.card(padding: 0)
			.padding(.horizontal, 12)
			.padding(.bottom, 108)
			.transition(.move(edge: .bottom).combined(with: .opacity))
		}
	}

	private func addToRetro() async {
		do {
			let r: Retro = try await API.shared.get("/api/retro")
			let ids = r.items.map(\.id) + selected.filter { id in !r.items.contains { $0.id == id } }
			let _: OK = try await API.shared.put("/api/admin/retro", RetroBody(mediaIds: ids))
			withAnimation { toast = "\(selected.count) na retrospectiva (\(ids.count) no total)." }
			selecting = false
			selected = []
			try? await Task.sleep(for: .seconds(3))
			withAnimation { toast = nil }
		} catch {
			app.handle(error)
			withAnimation { toast = error.localizedDescription }
		}
	}

	@ViewBuilder private var posts: some View {
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
	}
}

struct ReelStart: Identifiable { let id: String }

/// Diário (posts) or Todas as fotos (the grid).
private struct ModeSwitch: View {
	@Binding var grid: Bool

	var body: some View {
		HStack(spacing: 6) {
			item(false, .journal, "Diário")
			item(true, .grid, "Todas as fotos")
		}
		.padding(4)
		.background(Capsule().fill(Color.surface))
		.overlay(Capsule().strokeBorder(Color.line, lineWidth: 2.5))
		.animation(.bounce, value: grid)
	}

	private func item(_ value: Bool, _ icon: IconName, _ label: String) -> some View {
		Button { grid = value } label: {
			HStack(spacing: 6) { Icon(icon, size: 18); Text(label).font(.display(16)) }
				.foregroundStyle(grid == value ? Color.onSea : Color.muted)
				.frame(maxWidth: .infinity, minHeight: 40)
				.background(Capsule().fill(grid == value ? Color.sea : .clear))
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(grid == value ? .isSelected : [])
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
