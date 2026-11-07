import MapLibre
import SwiftUI

/// Mapa (web /mapa): everyone's located photos, check-ins, trails and latest positions,
/// with day/person filters, "Compartilhar local" and "Check-in".
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
	@State private var open: Route?
	@State private var checkingIn = false
	@State private var stamp: Date?
	private var sharing: LocationSharing { .shared }

	static let tripDays = ["2026-11-11", "2026-11-12", "2026-11-13", "2026-11-14", "2026-11-15", "2026-11-16", "2026-11-17", "2026-11-18"]
	static var today: String { TripTime.dayKey(Date().formatted(.iso8601)) }
	static var initialDay: String { tripDays.contains(today) ? today : "all" }

	private func visible(_ d: String, _ u: String) -> Bool { (day == "all" || d == day) && (person == nil || u == person) }

	private var items: [MapItem] { (data?.items ?? []).filter { visible($0.day, $0.userId) } }
	private var people: [LatestLocation] { (data?.latest ?? []).filter { person == nil || $0.userId == person } }

	/// Everything with a position, per person per day, in time order.
	private var trails: [Trail] {
		guard let data else { return [] }
		var points = data.pings.filter { visible($0.day, $0.userId) }.map { ($0.userId, $0.day, $0.at, $0.lat, $0.lng) }
		points += items.map { ($0.userId, $0.day, $0.at, $0.lat, $0.lng) }
		points.sort { $0.2 < $1.2 }
		var lines: [String: [CLLocationCoordinate2D]] = [:]
		var order: [String] = []
		for p in points {
			let k = "\(p.0)|\(p.1)"
			if lines[k] == nil { order.append(k) }
			lines[k, default: []].append(CLLocationCoordinate2D(latitude: p.3, longitude: p.4))
		}
		return order.compactMap { k in
			guard let c = lines[k], c.count > 1 else { return nil }
			let uid = String(k.split(separator: "|")[0])
			return Trail(userId: uid, color: app.person(uid)?.color ?? "#888888", coordinates: c)
		}
	}

	private var days: [String] { Array(Set(Self.tripDays + (data?.items.map(\.day) ?? []))).sorted() }

	var body: some View {
		ZStack {
			if let style {
				TripMap(styleURL: style, items: items, trails: trails, people: people,
						colors: Dictionary(uniqueKeysWithValues: app.people.map { ($0.id, $0.tint) }),
						fitToken: fitToken, flyTo: flyTo, onOpen: { open = $0 })
					.clipShape(RoundedRectangle(cornerRadius: Radius.card))
					.overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.line, lineWidth: 3))
					.padding(10)
			} else if let error {
				EmptyState(text: error, retry: { Task { await load() } })
			} else {
				ProgressView().tint(.sea)
			}
		}
		.overlay(alignment: .topLeading) { filters.padding(22) }
		.overlay(alignment: .bottom) { actions.padding(.horizontal, 22).padding(.bottom, 108) }
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

	private var actions: some View {
		VStack(spacing: 10) {
			if let e = sharing.error {
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

/// Pick a spot on the map ("Marcar no mapa" / "Corrigir local" on your own photos).
struct LocationPicker: View {
	let start: CLLocationCoordinate2D?
	let save: (CLLocationCoordinate2D) async throws -> Void
	@Environment(\.dismiss) private var dismiss
	@State private var style: URL?
	@State private var center: CLLocationCoordinate2D?
	@State private var busy = false
	@State private var error: String?

	var body: some View {
		VStack(spacing: 12) {
			Text("Arraste o mapa até o lugar da foto").font(.display(20)).foregroundStyle(Color.ink).padding(.top, 18)
			ZStack {
				if let style {
					TripMap(styleURL: style, initialCenter: start ?? LocationSharing.shared.last?.coordinate, initialZoom: start == nil ? 13 : 16,
							onCenter: { center = $0 })
				} else {
					ProgressView().tint(.sea)
				}
				PinMarker(color: .coral).frame(width: 56, height: 64).offset(y: -32).allowsHitTesting(false)
			}
			.clipShape(RoundedRectangle(cornerRadius: Radius.card))
			.overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.line, lineWidth: 3))
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
	}
}
