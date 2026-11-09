import MapLibre
import SwiftUI

/// Mapa (web /mapa): everyone's located photos, check-ins and latest positions,
/// with day/person filters, "Ir para onde estou", "Compartilhar local" and "Check-in".
struct MapaView: View {
	@Environment(AppState.self) private var app
	@State private var style: URL?
	@State private var data: MapData?
	@State private var error: String?
	@State private var day: String = MapaView.initialDay
	@State private var person: String?
	@State private var showFilters = false
	@State private var fitToken = 0
	@State private var flyTo: CLLocationCoordinate2D?
	@State private var flyToken = 0
	@State private var showsMe = false
	@State private var locating = false
	@State private var locateError: String?
	@State private var open: Route?
	@State private var checkingIn = false
	@State private var stamp: Date?
	private var sharing: LocationSharing { .shared }

	static let tripDays = TripTime.tripDays
	static var today: String { TripTime.dayKey(Date().formatted(.iso8601)) }
	static var initialDay: String { tripDays.contains(today) ? today : "all" }

	private func visible(_ d: String, _ u: String) -> Bool { (day == "all" || d == day) && (person == nil || u == person) }

	private var items: [MapItem] { (data?.items ?? []).filter { visible($0.day, $0.userId) } }
	private var people: [LatestLocation] { (data?.latest ?? []).filter { person == nil || $0.userId == person } }

	private var days: [String] { Array(Set(Self.tripDays + (data?.items.map(\.day) ?? []))).sorted() }

	var body: some View {
		ZStack {
			if let style {
				TripMap(styleURL: style, items: items, people: people,
						colors: Dictionary(uniqueKeysWithValues: app.people.map { ($0.id, $0.tint) }),
						fitToken: fitToken, flyTo: flyTo, flyToken: flyToken, showsUser: showsMe, onOpen: { open = $0 })
					.clipShape(RoundedRectangle(cornerRadius: Radius.card))
					.overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.line, lineWidth: 3))
					.padding(10)
			} else if let error {
				EmptyState(text: error, retry: { Task { await load() } }).padding(20)
			} else {
				ProgressView().tint(.sea)
			}
		}
		// fill the tab even while there's no map (otherwise the overlays below sit on the small error card)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		// filters and actions belong to the map: only once it has loaded
		.overlay(alignment: .topLeading) { if style != nil { filters.padding(22).padding(.trailing, 60) } }
		.overlay(alignment: .topTrailing) { if style != nil { locateButton.padding(22) } }
		.overlay(alignment: .bottom) { if style != nil { actions.padding(.horizontal, 22).padding(.bottom, 108) } }
		.overlay { if let stamp { StampToast(date: stamp).allowsHitTesting(false) } }
		.navigationDestination(item: $open) { route in
			Group {
				switch route {
				case .media(let id): MediaDetailView(id: id)
				case .checkin(let id): CheckinDetailView(id: id)
				}
			}
			.contentMargins(.bottom, 104, for: .scrollContent)
		}
		.sheet(isPresented: $checkingIn) { CheckinSheet { lat, lng in await checkedIn(lat, lng) } }
		.task { await load() }
		.task { await pollPeople() }
		// "Chegou em …? Fazer check-in" notification
		.onAppear { if Notifier.shared.openCheckin { Notifier.shared.openCheckin = false; checkingIn = true } }
		.onChange(of: Notifier.shared.openCheckin) { _, on in if on { Notifier.shared.openCheckin = false; checkingIn = true } }
		.onChange(of: day) { fitToken += 1 }
		.onChange(of: person) { fitToken += 1 }
		.onChange(of: app.feedVersion) { Task { await load(fit: false) } }
	}

	private var filters: some View {
		VStack(alignment: .leading, spacing: 8) {
			Button { withAnimation(.bounce) { showFilters.toggle() } } label: {
				Label { Text("Filtros" + (day != "all" || person != nil ? " •" : "")) } icon: { Icon(.calendar, size: 18) }
			}
			.buttonStyle(.chunky(.secondary, small: true))
			if showFilters {
				VStack(alignment: .leading, spacing: 10) {
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 8) {
							Chip(selected: day == "all", action: { day = "all" }) { Text("Todos os dias") }
							ForEach(days, id: \.self) { d in
								Chip(selected: day == d, dashed: true, action: { day = d }) { Text(String(d.suffix(2)) + "/" + String(d.dropFirst(5).prefix(2))) }
							}
						}
						.padding(.vertical, 4)
					}
					.noDockMargin()
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 8) {
							Chip(selected: person == nil, action: { person = nil }) { Label { Text("Todo mundo") } icon: { Icon(.people, size: 16) } }
							ForEach(app.people) { p in
								Chip(selected: person == p.id, tint: p.tint, action: { person = p.id }) { Text(p.name) }
							}
						}
						.padding(.vertical, 4)
					}
					.noDockMargin()
				}
				.padding(10)
				.card(padding: 0)
				.popIn()
			}
		}
	}

	/// Round map button: flies to where I am and shows the blue dot.
	private var locateButton: some View {
		Button { Task { await goToMe() } } label: {
			Group {
				if locating { ProgressView().tint(.ink) } else { Icon(.locate, size: 22).foregroundStyle(Color.ink) }
			}
			.frame(width: 44, height: 44)
			.background(RoundedRectangle(cornerRadius: 14).fill(Color.surface))
			.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, lineWidth: 2.5))
			.background(RoundedRectangle(cornerRadius: 14).fill(Color.shadow).offset(y: 3))
		}
		.buttonStyle(.plain)
		.disabled(locating)
		.accessibilityLabel("Ir para onde estou")
	}

	private func goToMe() async {
		locating = true
		locateError = nil
		defer { locating = false }
		do {
			let l: CLLocation
			if let last = sharing.last, Date().timeIntervalSince(last.timestamp) < 30 { l = last }
			else { l = try await LocationOnce.current() }
			showsMe = true
			flyTo = l.coordinate
			flyToken += 1
		} catch {
			locateError = (error as? LocalizedError)?.errorDescription ?? "Não foi possível pegar sua localização agora."
		}
	}

	private var actions: some View {
		VStack(spacing: 10) {
			if let e = locateError ?? sharing.error {
				Text(e).font(.text(14, .bold)).foregroundStyle(Color.danger).padding(10).card(padding: 0)
			}
			HStack(spacing: 10) {
				Button { sharing.sharing ? sharing.stop() : sharing.start() } label: {
					if sharing.sharing {
						HStack(spacing: 8) {
							Circle().fill(.white).frame(width: 10, height: 10)
								.phaseAnimator([false, true]) { v, up in v.offset(y: up ? -3 : 0) } animation: { _ in .easeInOut(duration: 0.5) }
							Text("Compartilhando")
						}
					} else {
						Label { Text("Compartilhar local").lineLimit(1).minimumScaleFactor(0.8) } icon: { Icon(.people, size: 20) }
					}
				}
				.buttonStyle(.chunky(sharing.sharing ? .leaf : .secondary))
				Button { checkingIn = true } label: { Label { Text("Check-in") } icon: { Icon(.pin, size: 20) } }
					.buttonStyle(.chunky(.sun))
			}
		}
	}

	private func load(fit: Bool = true) async {
		do {
			async let s = MapStyle.url()
			async let d: MapData = API.shared.get("/api/map")
			let (styleURL, mapData) = try await (s, d)
			style = styleURL
			data = mapData
			error = nil
			if fit { fitToken += 1 }
		} catch {
			app.handle(error)
			if data == nil { self.error = error.localizedDescription }
		}
	}

	/// Everyone's latest position, every 20 s while the map is open.
	private func pollPeople() async {
		while !Task.isCancelled {
			try? await Task.sleep(for: .seconds(20))
			if let latest: [LatestLocation] = try? await API.shared.get("/api/locations"), let d = data {
				data = MapData(items: d.items, pings: d.pings, latest: latest)
			}
		}
	}

	private func checkedIn(_ lat: Double, _ lng: Double) async {
		if day != "all" && day != Self.today { day = Self.today }
		flyTo = CLLocationCoordinate2D(latitude: lat, longitude: lng)
		await load(fit: false)
		app.feedChanged()
		withAnimation(.bounce) { stamp = Date() }
		Task {
			try? await Task.sleep(for: .seconds(2.6))
			withAnimation { stamp = nil }
		}
	}
}

/// "Check-in" sheet: a note, then a pin where you are, on the map and in everyone's diary.
struct CheckinSheet: View {
	let done: (Double, Double) async -> Void
	@Environment(AppState.self) private var app
	@Environment(\.dismiss) private var dismiss
	@State private var note = ""
	@State private var busy = false
	@State private var error: String?

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			TitleRow(icon: .pin, title: "Check-in")
			Text("Crava um alfinete onde você está agora, no mapa e no diário de todo mundo.")
				.font(.text(15)).foregroundStyle(Color.muted)
			TextField("O que está rolando? (opcional)", text: $note, axis: .vertical)
				.lineLimit(3...6)
				.font(.text(16)).foregroundStyle(Color.ink)
				.padding(12)
				.background(RoundedRectangle(cornerRadius: Radius.small).fill(Color.surface2))
				.overlay(RoundedRectangle(cornerRadius: Radius.small).strokeBorder(Color.line, lineWidth: 2))
			if let error { Text(error).font(.text(14, .bold)).foregroundStyle(Color.danger) }
			HStack {
				Button("Cancelar") { dismiss() }.buttonStyle(.chunky(.secondary))
				Spacer()
				Button(busy ? "Localizando…" : "Fazer check-in") { Task { await checkIn() } }
					.buttonStyle(.chunky(.sun))
					.disabled(busy)
			}
			Spacer(minLength: 0)
		}
		.padding(22)
		.presentationDetents([.medium])
		.presentationBackground(Color.bg)
	}

	private func checkIn() async {
		busy = true
		error = nil
		defer { busy = false }
		do {
			let l: CLLocation
			if let last = LocationSharing.shared.last, Date().timeIntervalSince(last.timestamp) < 30 { l = last }
			else { l = try await LocationOnce.current() }
			let body = CheckinBody(lat: l.coordinate.latitude, lng: l.coordinate.longitude, accuracy: l.horizontalAccuracy, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
			let created: CheckinCreated = try await API.shared.post("/api/checkins", body)
			// the map picture for the diary is made in the background; the feed shows a banner meanwhile
			if let me = app.me {
				Task {
					if await CheckinSnapshot.attach(checkinId: created.id, lat: body.lat, lng: body.lng, me: me) { app.feedChanged() }
				}
			}
			dismiss()
			await done(body.lat, body.lng)
		} catch {
			app.handle(error)
			self.error = (error as? LocalizedError)?.errorDescription ?? "Não foi possível salvar o check-in."
		}
	}
}

private struct CheckinBody: Encodable {
	let lat: Double
	let lng: Double
	let accuracy: Double
	let note: String
}

/// The round "CHECK-IN" stamp that lands on the map.
private struct StampToast: View {
	let date: Date

	var body: some View {
		VStack(spacing: 2) {
			Text("CHECK-IN").font(.display(24)).tracking(1.2)
			Text(TripTime.short(date)).font(.text(12, .bold))
		}
		.foregroundStyle(Color.coral)
		.frame(width: 150, height: 150)
		.background(Circle().fill(Color(red: 1, green: 0.988, blue: 0.941).opacity(0.88)))
		.overlay(Circle().strokeBorder(Color.coral, lineWidth: 2).padding(3))
		.overlay(Circle().strokeBorder(Color.coral, lineWidth: 2))
		.rotationEffect(.degrees(-8))
		.transition(.scale(scale: 2.4).combined(with: .opacity))
		.offset(y: -60)
	}
}

/// GET /api/places
struct PlaceResult: Decodable, Hashable, Sendable {
	let name: String
	let detail: String
	let lat: Double
	let lng: Double
}

/// Pick a spot on the map ("Marcar no mapa" / "Corrigir local" on your own photos): search a place by name,
/// or drag the map under the pin.
struct LocationPicker: View {
	let start: CLLocationCoordinate2D?
	let save: (CLLocationCoordinate2D) async throws -> Void
	/// A place picked in the search (the place editor fills in its name and address).
	var onPick: ((PlaceResult) -> Void)? = nil
	@Environment(AppState.self) private var app
	@Environment(\.dismiss) private var dismiss
	@State private var style: URL?
	@State private var center: CLLocationCoordinate2D?
	@State private var flyTo: CLLocationCoordinate2D?
	@State private var flyToken = 0
	@State private var busy = false
	@State private var error: String?
	@State private var query = ""
	@State private var results: [PlaceResult] = []
	@State private var searching = false
	@State private var searchNote: String?
	@State private var chosen: String?
	@FocusState private var searchFocused: Bool

	var body: some View {
		VStack(spacing: 12) {
			Text("Busque o lugar ou arraste o mapa até ele").font(.display(20)).foregroundStyle(Color.ink).padding(.top, 18)
				.multilineTextAlignment(.center)
			searchField
			ZStack(alignment: .top) {
				ZStack {
					if let style {
						TripMap(styleURL: style, flyTo: flyTo, flyToken: flyToken,
								initialCenter: start ?? LocationSharing.shared.last?.coordinate, initialZoom: start == nil ? 13 : 16,
								onCenter: { center = $0 })
					} else {
						ProgressView().tint(.sea)
					}
					PinMarker(color: .coral).frame(width: 56, height: 64).offset(y: -32).allowsHitTesting(false)
				}
				.clipShape(RoundedRectangle(cornerRadius: Radius.card))
				.overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.line, lineWidth: 3))
				if !results.isEmpty { resultsList.padding(.horizontal, 6).padding(.top, 6) }
			}
			if let error { Text(error).font(.text(14, .bold)).foregroundStyle(Color.danger) }
			HStack {
				Button("Cancelar") { dismiss() }.buttonStyle(.chunky(.secondary))
				Spacer()
				Button(busy ? "Salvando…" : "Usar este lugar") {
					guard let center else { return }
					Task {
						busy = true
						defer { busy = false }
						do { try await save(center); dismiss() } catch { self.error = error.localizedDescription }
					}
				}
				.buttonStyle(.chunky(.sun))
				.disabled(busy || center == nil)
			}
		}
		.padding(16)
		.background(DottedBackground())
		.task {
			style = try? await MapStyle.url()
			if style == nil { error = "Sem conexão para carregar o mapa." }
		}
		// search as you type, after a short pause
		.task(id: query) {
			let q = query.trimmingCharacters(in: .whitespaces)
			searchNote = nil
			if !q.isEmpty { chosen = nil }
			guard q.count >= 2 else { results = []; return }
			try? await Task.sleep(for: .milliseconds(350))
			guard !Task.isCancelled else { return }
			await search(q)
		}
	}

	private var searchField: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(spacing: 8) {
				Icon(.search, size: 18).foregroundStyle(Color.muted)
				TextField("Buscar lugar (ex.: Jardim Botânico)", text: $query)
					.font(.text(16)).foregroundStyle(Color.ink)
					.focused($searchFocused)
					.submitLabel(.search)
					.autocorrectionDisabled()
				if searching { ProgressView().tint(.sea) }
				else if !query.isEmpty {
					Button { query = ""; results = [] } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.muted) }
						.buttonStyle(.plain).accessibilityLabel("Limpar busca")
				}
			}
			.padding(.horizontal, 12)
			.frame(minHeight: 46)
			.background(RoundedRectangle(cornerRadius: 14).fill(Color.surface))
			.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(searchFocused ? Color.sea : Color.line, lineWidth: 2.5))
			if let note = searchNote ?? chosen.map({ "\($0). Arraste o mapa para ajustar." }) {
				Text(note).font(.text(14, .bold)).foregroundStyle(Color.muted)
			}
		}
	}

	private var resultsList: some View {
		ScrollView {
			VStack(spacing: 0) {
				ForEach(results, id: \.self) { r in
					Button { choose(r) } label: {
						HStack(alignment: .top, spacing: 8) {
							Icon(.pin, size: 16).foregroundStyle(Color.coral).padding(.top, 3)
							VStack(alignment: .leading, spacing: 1) {
								Text(r.name).font(.text(16, .extraBold)).foregroundStyle(Color.ink)
								if !r.detail.isEmpty { Text(r.detail).font(.text(13)).foregroundStyle(Color.muted).lineLimit(1) }
							}
							Spacer(minLength: 0)
						}
						.padding(.horizontal, 10).padding(.vertical, 8)
						.frame(minHeight: 44)
						.contentShape(Rectangle())
					}
					.buttonStyle(.plain)
				}
			}
			.padding(4)
		}
		.noDockMargin()
		.frame(maxHeight: 280)
		.fixedSize(horizontal: false, vertical: true)
		.card(padding: 0)
	}

	private func search(_ q: String) async {
		searching = true
		defer { searching = false }
		let c = center ?? start
		do {
			let found: [PlaceResult] = try await API.shared.get("/api/places", query: [
				"q": q,
				"lat": c.map { String(format: "%.4f", $0.latitude) },
				"lng": c.map { String(format: "%.4f", $0.longitude) }
			])
			guard !Task.isCancelled else { return }
			results = found
			if found.isEmpty { searchNote = "Nenhum lugar encontrado." }
		} catch {
			guard !Task.isCancelled else { return }
			app.handle(error)
			results = []
			searchNote = (error as? LocalizedError)?.errorDescription ?? "Não foi possível buscar."
		}
	}

	private func choose(_ r: PlaceResult) {
		let c = CLLocationCoordinate2D(latitude: r.lat, longitude: r.lng)
		flyTo = c
		flyToken += 1
		center = c
		searchFocused = false
		results = []
		chosen = r.name
		onPick?(r)
		query = ""
	}
}
