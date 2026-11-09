import SwiftUI

/// Roteiro (web /roteiro), the same for everyone; only admins change places and days (everyone ticks "Fomos!"):
/// - **Dia a dia:** day chips, a boarding-pass ticket per day with the route map and the stops ("Fomos?", Uber, Maps).
/// - **Lugares:** every place to go or eat, with photos, hours, prices and "Pôr no roteiro".
/// - **Hospedagem:** where everyone sleeps (admins set it up); each day leaves from and comes back to it.
struct RoteiroView: View {
	@Environment(AppState.self) private var app
	@Environment(\.openURL) private var openURL
	@State private var data: RoteiroData?
	@State private var style: URL?
	@State private var error: String?
	@State private var tab = 0
	@State private var selected: String?
	@State private var editingDay: DayEdit?
	@State private var editingPlace: PlaceEdit?
	@State private var editingStay: StayEdit?
	@State private var filter: RoteiroCategory?
	@State private var query = ""
	@State private var toast: String?
	@State private var scrollTo: String?

	private var days: [RoteiroDay] { data?.days ?? [] }
	private var places: [RoteiroPlace] { data?.places ?? [] }
	private var day: RoteiroDay? { days.first { $0.date == selected } ?? days.first }
	private var stays: [RoteiroStay] { data?.stays ?? [] }
	private func place(_ id: String?) -> RoteiroPlace? { id.flatMap { id in places.first { $0.id == id } } }
	private func stay(_ id: String?) -> RoteiroStay? { id.flatMap { id in stays.first { $0.id == id } } }

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView {
				VStack(alignment: .leading, spacing: 14) {
					TitleRow(icon: .ticket, title: "Roteiro")
					tabs
					if let error, data == nil { EmptyState(text: error, retry: { Task { await load() } }) }
					switch tab {
					case 0: daysView
					case 1: placesView
					default: staysView
					}
				}
				.padding(16)
				.frame(maxWidth: 640)
				.frame(maxWidth: .infinity)
			}
			.onChange(of: scrollTo) { _, id in
				guard let id else { return }
				withAnimation { proxy.scrollTo(id, anchor: .center) }
				scrollTo = nil
			}
		}
		.refreshable { await load() }
		.overlay(alignment: .top) {
			if let toast {
				Text(toast).font(.text(15, .extraBold)).foregroundStyle(Color.onLeaf)
					.padding(.horizontal, 14).padding(.vertical, 10)
					.background(RoundedRectangle(cornerRadius: 14).fill(Color.leaf))
					.padding(.top, 8).padding(.horizontal, 16)
					.transition(.move(edge: .top).combined(with: .opacity))
			}
		}
		.task { await load() }
		.sheet(item: $editingDay) { e in
			DayEditor(day: e.day, places: places, takenDates: days.map(\.date), suggestedDate: e.suggested,
					  saved: { date in Task { await load(); if let date { selected = date } } },
					  placesChanged: { Task { await load() } })
		}
		.sheet(item: $editingPlace) { e in
			PlaceEditor(place: e.place, changed: { Task { await load() } })
		}
		.sheet(item: $editingStay) { e in
			StayEditor(stay: e.stay, firstDay: days.first?.date ?? TripTime.dayKey(Date().formatted(.iso8601)),
					   lastDay: days.last?.date ?? TripTime.dayKey(Date().formatted(.iso8601)),
					   changed: { Task { await load(); Roteiro.itineraryChanged() } })
		}
	}

	/// "Dia a dia" / "Lugares": the sea-blue pill switch (web .tabs).
	private var tabs: some View {
		HStack(spacing: 6) {
			ForEach([(0, "Dia a dia", IconName.calendar), (1, "Lugares", IconName.pin), (2, "Hospedagem", IconName.home)], id: \.0) { i, label, icon in
				Button { withAnimation(.bounce) { tab = i } } label: {
					Label { Text(label).lineLimit(1).minimumScaleFactor(0.75) } icon: { Icon(icon, size: 16) }
						.labelStyle(TightLabel())
						.font(.display(15))
						.foregroundStyle(tab == i ? Color.onSea : Color.muted)
						.frame(maxWidth: .infinity, minHeight: 42)
						.background {
							if tab == i {
								Capsule().fill(Color.sea).background(Capsule().fill(Color.seaDark).offset(y: 3))
							}
						}
						.contentShape(Capsule())
				}
				.buttonStyle(.plain)
				.accessibilityAddTraits(tab == i ? .isSelected : [])
			}
		}
		.padding(5)
		.background(Capsule().fill(Color.surface))
		.overlay(Capsule().strokeBorder(Color.line, lineWidth: 2.5))
	}

	// MARK: Dia a dia

	@ViewBuilder private var daysView: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				ForEach(days) { d in
					Chip(selected: d.id == day?.id, dashed: true, tint: d.wedding ? .berry : nil, action: { withAnimation(.bounce) { selected = d.id } }) {
						VStack(spacing: 0) {
							Text(String(d.date.suffix(2))).font(.display(17))
							Text(TripTime.shortWeekday(d.date)).font(.text(11, .extraBold))
						}
						.padding(.vertical, 4)
					}
				}
				if isAdmin {
					Chip(dashed: true, tint: .sea, action: { editingDay = DayEdit(day: nil, suggested: nextDate) }) {
						VStack(spacing: 0) { Text("+").font(.display(17)); Text("dia").font(.text(11, .extraBold)) }.padding(.vertical, 4)
					}
					.accessibilityLabel("Adicionar dia")
				}
			}
			.padding(.vertical, 6)
			.padding(.horizontal, 2)
		}
		.noDockMargin()
		if let day { ticket(day).id(day.id).transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity)) }
		else if data != nil {
			VStack(spacing: 12) {
				Text("O roteiro ainda está vazio.").font(.text(16)).foregroundStyle(Color.ink)
				if isAdmin { Button("Criar o primeiro dia") { editingDay = DayEdit(day: nil, suggested: nextDate) }.buttonStyle(.chunky(.sun)) }
			}
			.frame(maxWidth: .infinity).card(padding: 24)
		}
	}

	private var nextDate: String {
		guard let last = days.last?.date, let d = TripTime.date("\(last)T12:00:00.000-03:00") else { return TripTime.dayKey(Date().formatted(.iso8601)) }
		return TripTime.dayKey(d.addingTimeInterval(86_400).formatted(.iso8601))
	}

	/// The day's stops with a place, numbered for the map.
	private func points(_ d: RoteiroDay) -> [(stop: String, point: RoutePoint)] {
		var n = 0
		return d.stops.compactMap { s in
			guard let p = place(s.placeId) else { return nil }
			n += 1
			return (s.id, RoutePoint(n: n, name: p.name, coordinate: p.coordinate, photo: p.photos.first?.url, visited: s.visitedAt != nil))
		}
	}

	@ViewBuilder private func ticket(_ d: RoteiroDay) -> some View {
		let index = (days.firstIndex { $0.id == d.id } ?? 0) + 1
		let pts = points(d)
		let numbers = Dictionary(uniqueKeysWithValues: pts.map { ($0.stop, $0.point.n) })
		// only on days with somewhere to go
		let start = pts.isEmpty ? nil : stay(d.startStay), end = pts.isEmpty ? nil : stay(d.endStay)
		let homes = homes(start: start, end: end)
		VStack(spacing: 0) {
			HStack(alignment: .center, spacing: 12) {
				VStack(alignment: .leading, spacing: 2) {
					Text(d.wedding ? "DIA ESPECIAL" : "DIA \(index) DE \(days.count)").font(.text(12, .extraBold)).kerning(1.2).opacity(0.9)
					Text(d.title.isEmpty ? "Sem título" : d.title).font(.display(24))
				}
				Spacer()
				VStack(spacing: -2) {
					Text(String(d.date.suffix(2))).font(.display(26))
					Text(month(d.date)).font(.text(11, .extraBold))
				}
				.frame(width: 64, height: 64)
				.overlay(Circle().strokeBorder(.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [5, 4])))
				.rotationEffect(.degrees(10))
			}
			.foregroundStyle(.white)
			.padding(16)
			.background(d.wedding ? Color.berry : Color.seaDark)

			DashedLine().stroke(Color.line, style: StrokeStyle(lineWidth: 3, dash: [7, 5])).frame(height: 3).padding(.horizontal, 14)

			VStack(alignment: .leading, spacing: 12) {
				if !d.who.isEmpty {
					Label { Text(d.who) } icon: { Icon(.people, size: 16) }.font(.text(14, .bold)).foregroundStyle(Color.muted)
				}
				if !d.lead.isEmpty { Text(d.lead).font(.text(17)).foregroundStyle(Color.ink) }
				if !pts.isEmpty, let style {
					RouteMap(styleURL: style, date: d.date, points: pts.map(\.point), homes: homes,
							 onPick: { scrollTo = "parada-\($0)" }, onPickHome: { scrollTo = "casa-\($0)" })
						.frame(height: 260)
						.clipShape(RoundedRectangle(cornerRadius: 18))
						.overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.line, lineWidth: 2.5))
					legend(d, back: end != nil)
				}
				if let start { homeStop(start, start: true).id("casa-start") }
				ForEach(Array(d.stops.enumerated()), id: \.element.id) { i, s in
					stop(s, n: numbers[s.id]).id(numbers[s.id].map { "parada-\($0)" } ?? s.id).popIn(delay: 0.1 + Double(i) * 0.07)
				}
				if d.stops.isEmpty { Text("Nenhuma parada ainda.").font(.text(15)).foregroundStyle(Color.muted) }
				if let end { homeStop(end, start: false).id("casa-end") }
				if let route = Roteiro.routeURL([start?.coordinate].compactMap { $0 } + d.stops.compactMap { place($0.placeId)?.coordinate } + [end?.coordinate].compactMap { $0 }),
				   !d.wedding {
					Button { openURL(route) } label: { Label { Text("Rota do dia no Google Maps") } icon: { Icon(.map, size: 20) } }
						.buttonStyle(.chunky(.sea, fullWidth: true))
				}
				if isAdmin {
					Button { editingDay = DayEdit(day: d, suggested: d.date) } label: { Text("✎ Editar este dia") }
						.buttonStyle(.chunky(.secondary, fullWidth: true))
				}
			}
			.padding(16)
		}
		.background(Color.surface)
		.clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
		.overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(d.wedding ? Color.berry : Color.line, lineWidth: 2.5))
		.background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.shadow).offset(y: 5))
	}

	/// The stay pin(s): one when you leave from and come back to the same place.
	private func homes(start: RoteiroStay?, end: RoteiroStay?) -> [RouteHome] {
		let pin = { (s: RoteiroStay, id: String, label: String) in RouteHome(id: id, name: s.name, emoji: s.emoji, label: label, coordinate: s.coordinate) }
		if let start, let end, start.id == end.id { return [pin(start, "start", "Saída e volta")] }
		return [start.map { pin($0, "start", "Saída") }, end.map { pin($0, "end", "Volta") }].compactMap { $0 }
	}

	/// "Saída" / "Volta": where you sleep, at the start and end of the day.
	private func homeStop(_ st: RoteiroStay, start: Bool) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .top, spacing: 10) {
				Text(st.emoji).font(.system(size: 32))
					.frame(width: 76, height: 76)
					.background(RoundedRectangle(cornerRadius: 14).fill(Color.sea.opacity(0.22)))
				VStack(alignment: .leading, spacing: 5) {
					Label { Text(start ? "Saída" : "Volta") } icon: { Icon(.home, size: 13) }
						.labelStyle(TightLabel())
						.font(.display(13)).foregroundStyle(Color.onSea)
						.padding(.horizontal, 10).padding(.vertical, 2)
						.background(RoundedRectangle(cornerRadius: 10).fill(Color.sea))
					Text(st.name).font(.display(19)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
					if !st.address.isEmpty { Text(st.address).font(.text(13)).foregroundStyle(Color.muted) }
				}
			}
			HStack(spacing: 8) {
				if !start {
					Button { openURL(st.uberURL) } label: { Label { Text("Uber de volta") } icon: { Icon(.car, size: 18) } }
						.buttonStyle(.chunky(.uber, small: true))
				}
				Button { openURL(st.mapsURL) } label: { Icon(.map, size: 18) }
					.buttonStyle(.chunky(.secondary, small: true))
					.accessibilityLabel("Abrir \(st.name) no Google Maps")
			}
		}
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.sea, style: StrokeStyle(lineWidth: 2.5, dash: [7, 5])))
	}

	private func legend(_ d: RoteiroDay, back: Bool = false) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 12) {
				ForEach(RoteiroTransport.allCases.filter { t in d.stops.contains { $0.transport == t.rawValue } }) { t in
					HStack(spacing: 5) {
						Capsule().fill(t.color).frame(width: 18, height: 4)
						Text(t.label).font(.text(12, .bold)).foregroundStyle(Color.muted)
					}
				}
			}
			if back {
				HStack(spacing: 5) {
					HStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in Circle().fill(Color.muted).frame(width: 4, height: 4) } }
					Text("Pontilhado: a volta para a hospedagem").font(.text(12, .bold)).foregroundStyle(Color.muted)
				}
			}
		}
	}

	private func stop(_ s: RoteiroStop, n: Int?) -> some View {
		let p = place(s.placeId)
		let t = RoteiroTransport.of(s.transport)
		let visited = s.visitedAt != nil
		return VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .top, spacing: 10) {
				if let p { stopPhoto(p) }
				VStack(alignment: .leading, spacing: 5) {
					HStack(spacing: 6) {
						if let n {
							Text("\(n)").font(.display(13)).foregroundStyle(Color.onSun)
								.frame(width: 24, height: 24).background(Circle().fill(Color.sun))
						}
						if !s.time.isEmpty {
							Text(s.time).font(.display(13))
								.foregroundStyle(visited ? Color.onLeaf : Color.onSun)
								.padding(.horizontal, 10).padding(.vertical, 2)
								.background(RoundedRectangle(cornerRadius: 10).fill(visited ? Color.leaf : Color.sun))
						}
					}
					Text(p?.name ?? s.label).font(.display(19)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
					HStack(spacing: 6) {
						badge(t.label, t.color)
						if let p { badge(p.categoryInfo.label, p.categoryInfo.color) }
					}
				}
			}
			if !s.note.isEmpty { Text(s.note).font(.text(15)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true) }
			if let at = s.visitedAt {
				Label {
					Text("Fomos! Marcado por \(s.visitedBy == app.me?.id ? "você" : (app.person(s.visitedBy ?? "")?.name ?? "alguém")) em \(TripTime.date(at).map(TripTime.short) ?? "")")
				} icon: { Icon(.check, size: 15) }
				.font(.text(14, .extraBold)).foregroundStyle(Color.leaf)
			}
			if let p {
				if !p.hours.isEmpty { Text("Horário: \(p.hours)").font(.text(13)).foregroundStyle(Color.muted) }
				if !p.price.isEmpty || p.priceLevel != nil {
					Text("Preço: \(Roteiro.priceSigns(p.priceLevel)) \(p.price)").font(.text(13)).foregroundStyle(Color.muted)
				}
				HStack(spacing: 8) {
					Button { openURL(p.uberURL) } label: { Label { Text("Pedir Uber") } icon: { Icon(.car, size: 18) } }
						.buttonStyle(.chunky(.uber, small: true))
					Button { openURL(p.mapsURL) } label: { Icon(.map, size: 18) }
						.buttonStyle(.chunky(.secondary, small: true))
						.accessibilityLabel("Abrir no Google Maps")
					if isAdmin {
						Button { editingPlace = PlaceEdit(place: p) } label: { Text("✎") }
							.buttonStyle(.chunky(.secondary, small: true))
							.accessibilityLabel("Editar lugar")
					}
				}
				Button { Task { await toggleVisit(s) } } label: {
					Label { Text(visited ? "Fomos!" : "Fomos?") } icon: { Icon(.check, size: 18) }
				}
				.buttonStyle(.chunky(visited ? .leaf : .secondary, small: true, fullWidth: true))
				.accessibilityAddTraits(visited ? .isSelected : [])
			}
		}
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(RoundedRectangle(cornerRadius: 18).fill(Color.surface2.opacity(0.4)))
		.overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(visited ? Color.leaf : Color.line, lineWidth: 2.5))
	}

	/// The place's first photo, or a dashed "foto" square that opens the place editor.
	private func stopPhoto(_ p: RoteiroPlace) -> some View {
		Group {
			if let photo = p.photos.first?.url {
				RemoteImage(url: photo)
			} else if !isAdmin {
				Icon(.pin, size: 22).foregroundStyle(p.categoryInfo.color)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.background(p.categoryInfo.color.opacity(0.18))
			} else {
				Button { editingPlace = PlaceEdit(place: p) } label: {
					VStack(spacing: 2) { Icon(.camera, size: 22); Text("foto").font(.text(11, .extraBold)) }
						.foregroundStyle(p.categoryInfo.color)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.background(p.categoryInfo.color.opacity(0.18))
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Adicionar foto de \(p.name)")
			}
		}
		.frame(width: 76, height: 76)
		.clipShape(RoundedRectangle(cornerRadius: 14))
		.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, style: StrokeStyle(lineWidth: 2, dash: p.photos.isEmpty ? [5, 4] : [])))
	}

	private func badge(_ text: String, _ color: Color) -> some View {
		Text(text).font(.text(12, .extraBold)).foregroundStyle(color)
			.padding(.horizontal, 9).padding(.vertical, 1)
			.overlay(Capsule().strokeBorder(color, lineWidth: 2))
	}

	private func month(_ date: String) -> String {
		["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"][max(0, min(11, (Int(date.dropFirst(5).prefix(2)) ?? 11) - 1))]
	}

	// MARK: Hospedagem

	private var isAdmin: Bool { app.me?.isAdmin == true }

	@ViewBuilder private var staysView: some View {
		Text("O dia a dia de cada pessoa começa e termina onde ela está hospedada." + (isAdmin ? "" : " Só administradores mudam a hospedagem."))
			.font(.text(14)).foregroundStyle(Color.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
		if isAdmin && !stays.isEmpty {
			Button("＋ Hospedagem") { editingStay = StayEdit(stay: nil) }.buttonStyle(.chunky(.sun, small: true)).frame(maxWidth: .infinity)
			let homeless = app.people.filter { p in !stays.contains { $0.guests.contains(p.id) } }
			if !homeless.isEmpty {
				Text("Sem hospedagem: " + homeless.map(\.name).joined(separator: ", "))
					.font(.text(13, .extraBold)).foregroundStyle(Color.coral).multilineTextAlignment(.center).frame(maxWidth: .infinity)
			}
		}
		ForEach(stays) { st in
			StayCard(stay: st, mine: st.guests.contains(app.me?.id ?? ""), edit: isAdmin ? { editingStay = StayEdit(stay: st) } : nil)
		}
		if stays.isEmpty && data != nil {
			VStack(spacing: 12) {
				Text("Nenhuma hospedagem cadastrada ainda.").font(.text(15)).foregroundStyle(Color.muted)
				if isAdmin { Button("Cadastrar hotel ou Airbnb") { editingStay = StayEdit(stay: nil) }.buttonStyle(.chunky(.sun)) }
			}
			.frame(maxWidth: .infinity).card(padding: 24)
		}
	}

	// MARK: Lugares

	private var shownPlaces: [RoteiroPlace] {
		let fold: (String) -> String = { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) }
		let q = fold(query.trimmingCharacters(in: .whitespaces))
		return places.filter { p in
			(filter == nil || p.category == filter?.rawValue) && (q.isEmpty || fold("\(p.name) \(p.address) \(p.description)").contains(q))
		}
	}

	private var visitedPlaces: Set<String> { Set(days.flatMap { $0.stops.filter { $0.visitedAt != nil }.compactMap(\.placeId) }) }

	@ViewBuilder private var placesView: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				Chip(selected: filter == nil, action: { filter = nil }) { Text("Todos") }
				ForEach(RoteiroCategory.allCases) { c in Chip(selected: filter == c, action: { filter = c }) { Text(c.plural) } }
			}
			.padding(.vertical, 4)
		}
		.noDockMargin()
		HStack(spacing: 10) {
			HStack(spacing: 8) {
				Icon(.search, size: 18).foregroundStyle(Color.muted)
				TextField("Procurar", text: $query).font(.text(16)).foregroundStyle(Color.ink).autocorrectionDisabled()
			}
			.padding(.horizontal, 12).frame(minHeight: 44)
			.background(RoundedRectangle(cornerRadius: 14).fill(Color.surface))
			.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, lineWidth: 2.5))
			if isAdmin { Button("＋ Lugar") { editingPlace = PlaceEdit(place: nil) }.buttonStyle(.chunky(.sun, small: true)) }
		}
		ForEach(shownPlaces) { p in
			PlaceCard(place: p, visited: visitedPlaces.contains(p.id),
					  usedOn: days.filter { $0.stops.contains { $0.placeId == p.id } }.map(\.date),
					  days: days, edit: isAdmin ? { editingPlace = PlaceEdit(place: p) } : nil,
					  add: isAdmin ? { date in Task { await add(p, to: date) } } : nil)
		}
		if shownPlaces.isEmpty && data != nil {
			Text(query.isEmpty ? "Nenhum lugar aqui ainda." : "Nenhum lugar com esse nome.").font(.text(15)).foregroundStyle(Color.muted)
		}
	}

	// MARK: Actions

	private func load() async {
		do {
			async let d: RoteiroData = API.shared.get("/api/roteiro")
			async let s = MapStyle.url()
			let loaded = try await d
			data = loaded
			style = try? await s
			if selected == nil || !loaded.days.contains(where: { $0.date == selected }) {
				let today = TripTime.dayKey(Date().formatted(.iso8601))
				selected = loaded.days.first { $0.date == today }?.date ?? loaded.days.first?.date
			}
			error = nil
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}

	/// "Fomos!": one tick counts for the whole group.
	private func toggleVisit(_ s: RoteiroStop) async {
		do {
			let r: VisitResult = try await API.shared.post("/api/roteiro/stops/\(s.id)/visited", VisitBody(visited: s.visitedAt == nil))
			if var d = data, let di = d.days.firstIndex(where: { $0.stops.contains { $0.id == s.id } }),
			   let si = d.days[di].stops.firstIndex(where: { $0.id == s.id }) {
				d.days[di].stops[si].visitedAt = r.visitedAt
				d.days[di].stops[si].visitedBy = r.visitedBy
				withAnimation(.bounce) { data = d }
			}
		} catch {
			app.handle(error)
			show(error.localizedDescription)
		}
	}

	/// "Pôr no roteiro": the place becomes the last stop of that day.
	private func add(_ p: RoteiroPlace, to date: String) async {
		guard let d = days.first(where: { $0.date == date }) else { return }
		var body = DayBody(d)
		body.stops.append(.init(id: nil, time: "", placeId: p.id, label: "", transport: "uber", note: ""))
		do {
			let _: OK = try await API.shared.put("/api/roteiro/days/\(date)", body)
			Roteiro.itineraryChanged()
			await load()
			show("\(p.name) entrou no roteiro de \(TripTime.shortWeekday(date)) \(date.suffix(2)).")
		} catch {
			app.handle(error)
			show(error.localizedDescription)
		}
	}

	private func show(_ text: String) {
		withAnimation(.bounce) { toast = text }
		Task {
			try? await Task.sleep(for: .seconds(3))
			withAnimation { toast = nil }
		}
	}
}

private struct DayEdit: Identifiable {
	let id = UUID()
	let day: RoteiroDay?
	let suggested: String
}

private struct StayEdit: Identifiable {
	let id = UUID()
	let stay: RoteiroStay?
}

private struct PlaceEdit: Identifiable {
	let id = UUID()
	let place: RoteiroPlace?
}

/// A place in "Lugares": photos to swipe, type, "Fomos!", address, hours, price, about, days, Uber and Maps.
private struct PlaceCard: View {
	let place: RoteiroPlace
	let visited: Bool
	let usedOn: [String]
	let days: [RoteiroDay]
	/// admins only
	let edit: (() -> Void)?
	let add: ((String) -> Void)?
	@Environment(\.openURL) private var openURL

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			ZStack(alignment: .topLeading) {
				if place.photos.isEmpty, let edit {
					Button(action: edit) {
						VStack(spacing: 6) { Icon(.camera, size: 26); Text("Adicionar fotos").font(.text(14, .extraBold)) }
							.foregroundStyle(Color.muted)
							.frame(maxWidth: .infinity, maxHeight: .infinity)
							.background(Color.surface2)
					}
					.buttonStyle(.plain)
				} else if place.photos.isEmpty {
					VStack(spacing: 6) { Icon(.camera, size: 26); Text("Sem fotos ainda").font(.text(14, .extraBold)) }
						.foregroundStyle(Color.muted)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.background(Color.surface2)
				} else {
					TabView {
						ForEach(place.photos) { ph in RemoteImage(url: ph.url) }
					}
					.tabViewStyle(.page(indexDisplayMode: place.photos.count > 1 ? .always : .never))
				}
				HStack {
					Text(place.categoryInfo.label).font(.text(12, .extraBold)).foregroundStyle(.white)
						.padding(.horizontal, 10).padding(.vertical, 2).background(Capsule().fill(place.categoryInfo.color))
					Spacer()
					if visited {
						Label { Text("Fomos!") } icon: { Icon(.check, size: 13) }
							.font(.text(12, .extraBold)).foregroundStyle(Color.onLeaf)
							.padding(.horizontal, 10).padding(.vertical, 2).background(Capsule().fill(Color.leaf))
					}
				}
				.padding(10)
				.allowsHitTesting(false)
			}
			.aspectRatio(16 / 10, contentMode: .fit)
			.clipped()

			VStack(alignment: .leading, spacing: 6) {
				Text(place.name).font(.display(20)).foregroundStyle(Color.ink)
				if !place.address.isEmpty {
					Label { Text(place.address) } icon: { Icon(.pin, size: 14) }.font(.text(13)).foregroundStyle(Color.muted)
				}
				if !place.hours.isEmpty { row("Horário", Text(place.hours)) }
				if !place.price.isEmpty || place.priceLevel != nil {
					row("Preço", Text("\(Text(Roteiro.priceSigns(place.priceLevel)).foregroundStyle(Color.sun).bold()) \(place.price)"))
				}
				if !place.description.isEmpty { Text(place.description).font(.text(15)).foregroundStyle(Color.ink) }
				if !usedOn.isEmpty {
					Label { Text("No roteiro: " + usedOn.map { "\(TripTime.shortWeekday($0)) \($0.suffix(2))" }.joined(separator: ", ")) } icon: { Icon(.ticket, size: 14) }
						.font(.text(13, .bold)).foregroundStyle(Color.leaf)
				}
				HStack(spacing: 8) {
					Button { openURL(place.uberURL) } label: { Label { Text("Pedir Uber") } icon: { Icon(.car, size: 18) } }
						.buttonStyle(.chunky(.uber, small: true))
					Button { openURL(place.mapsURL) } label: { Label { Text("Maps") } icon: { Icon(.map, size: 18) } }
						.buttonStyle(.chunky(.secondary, small: true))
					if let url = place.linkURL {
						Button { openURL(url) } label: { Icon(.expand, size: 16) }
							.buttonStyle(.chunky(.secondary, small: true))
							.accessibilityLabel("Site ou Instagram")
					}
				}
				.padding(.top, 4)
				if let add, let edit {
					HStack {
						Menu {
							ForEach(days) { d in
								Button("\(TripTime.shortWeekday(d.date)) \(d.date.suffix(2)) · \(d.title)") { add(d.date) }
							}
						} label: {
							Text("+ Pôr no roteiro…").font(.text(14, .extraBold)).foregroundStyle(Color.sea)
						}
						Spacer()
						Button("Editar", action: edit).font(.text(15, .extraBold)).foregroundStyle(Color.sea)
					}
					.frame(minHeight: 44)
				}
			}
			.padding(14)
		}
		.card(padding: 0)
		.popIn()
	}

	private func row(_ label: String, _ value: Text) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 8) {
			Text(label).font(.text(13, .extraBold)).foregroundStyle(Color.muted).frame(width: 60, alignment: .leading)
			value.font(.text(15)).foregroundStyle(Color.ink)
		}
	}
}

/// A stay in "Hospedagem": type, dates, address, who sleeps there, Uber, Maps and the booking link.
private struct StayCard: View {
	let stay: RoteiroStay
	let mine: Bool
	/// admins only
	var edit: (() -> Void)? = nil
	@Environment(AppState.self) private var app
	@Environment(\.openURL) private var openURL

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 12) {
				Text(stay.emoji).font(.system(size: 30))
					.frame(width: 56, height: 56)
					.background(RoundedRectangle(cornerRadius: 14).fill(Color.sea.opacity(0.22)))
				VStack(alignment: .leading, spacing: 4) {
					Text(stay.name).font(.display(20)).foregroundStyle(Color.ink)
					HStack(spacing: 6) {
						pill(stay.kindLabel, .sea)
						if mine { pill("Você fica aqui", .leaf) }
					}
				}
			}
			HStack(spacing: 16) {
				Text("\(Text("Chegada").bold()) \(stay.checkIn.map(day) ?? "início da viagem")")
				Text("\(Text("Saída").bold()) \(stay.checkOut.map(day) ?? "fim da viagem")")
			}
			.font(.text(14)).foregroundStyle(Color.ink)
			if !stay.address.isEmpty { Text(stay.address).font(.text(13)).foregroundStyle(Color.muted) }
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 6) {
					ForEach(stay.guests, id: \.self) { g in
						if let p = app.person(g) {
							HStack(spacing: 6) {
								AvatarView(name: p.name, color: p.tint, photo: p.photo, size: 26)
								Text(p.name).font(.text(14, .extraBold)).foregroundStyle(Color.ink)
							}
							.padding(.leading, 2).padding(.trailing, 10).padding(.vertical, 2)
							.background(Capsule().fill(Color.surface2))
						}
					}
				}
				.padding(.vertical, 2)
			}
			if !stay.note.isEmpty { Text(stay.note).font(.text(14)).foregroundStyle(Color.ink) }
			HStack(spacing: 8) {
				Button { openURL(stay.uberURL) } label: { Label { Text("Pedir Uber") } icon: { Icon(.car, size: 18) } }
					.buttonStyle(.chunky(.uber, small: true))
				Button { openURL(stay.mapsURL) } label: { Icon(.map, size: 18) }
					.buttonStyle(.chunky(.secondary, small: true))
					.accessibilityLabel("Abrir no Google Maps")
				if let url = stay.linkURL {
					Button { openURL(url) } label: { Text("Reserva") }.buttonStyle(.chunky(.secondary, small: true))
				}
				if let edit {
					Button(action: edit) { Text("✎") }.buttonStyle(.chunky(.secondary, small: true)).accessibilityLabel("Editar \(stay.name)")
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.card(padding: 14)
		.overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(mine ? Color.leaf : .clear, lineWidth: 2.5))
		.popIn()
	}

	private func day(_ key: String) -> String { "\(TripTime.shortWeekday(key)) \(key.suffix(2))/\(key.dropFirst(5).prefix(2))" }

	private func pill(_ text: String, _ color: Color) -> some View {
		Text(text).font(.text(12, .extraBold)).foregroundStyle(color)
			.padding(.horizontal, 9).padding(.vertical, 1)
			.overlay(Capsule().strokeBorder(color, lineWidth: 2))
	}
}

/// Icon and text closer together than the default Label.
private struct TightLabel: LabelStyle {
	func makeBody(configuration: Configuration) -> some View {
		HStack(spacing: 4) { configuration.icon; configuration.title }
	}
}

private struct DashedLine: Shape {
	func path(in rect: CGRect) -> Path {
		var p = Path()
		p.move(to: CGPoint(x: 0, y: rect.midY))
		p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
		return p
	}
}
