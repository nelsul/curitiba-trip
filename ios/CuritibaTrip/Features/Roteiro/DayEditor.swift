import SwiftUI

/// Edits a whole day (web DayEditor): title, who, tip, wedding, and the ordered stops (time, place or text,
/// how to get there, note). Saving replaces the day for everyone; ticks ("Fomos!") stay with their stops.
struct DayEditor: View {
	/// nil = new day
	let day: RoteiroDay?
	let places: [RoteiroPlace]
	let takenDates: [String]
	let suggestedDate: String
	/// The saved date (nil when the day was deleted).
	let saved: (String?) -> Void
	let placesChanged: () -> Void

	private struct EditStop: Identifiable {
		let id = UUID()
		var stopId: String?
		var useClock: Bool
		var minutes: Int
		var text: String
		var placeId: String
		var label: String
		var transport: RoteiroTransport
		var note: String
	}

	@Environment(AppState.self) private var app
	@Environment(\.dismiss) private var dismiss
	@State private var date = Date()
	@State private var title = ""
	@State private var who = ""
	@State private var lead = ""
	@State private var wedding = false
	@State private var stops: [EditStop] = []
	@State private var busy = false
	@State private var error: String?
	@State private var confirmDelete = false
	@State private var newPlaceFor: NewPlace?
	@State private var loaded = false

	var body: some View {
		NavigationStack {
			Form {
				Section {
					if day == nil {
						DatePicker("Data", selection: $date, displayedComponents: .date)
							.environment(\.timeZone, TripTime.zone)
					}
					TextField("Título do dia", text: $title)
					TextField("Quem vai", text: $who)
					TextField("Resumo / dica do dia", text: $lead, axis: .vertical).lineLimit(2...6)
					Toggle("Dia do casamento", isOn: $wedding)
				}.listRowBackground(Color.surface)
				ForEach($stops) { $s in
					let i = stops.firstIndex { $0.id == s.id } ?? 0
					Section("Parada \(i + 1)") {
						Picker("Lugar", selection: $s.placeId) {
							Text("Sem lugar (só texto)").tag("")
							ForEach(RoteiroCategory.allCases) { c in
								let list = places.filter { $0.category == c.rawValue }
								if !list.isEmpty {
									Section(c.plural) { ForEach(list) { p in Text(p.name).tag(p.id) } }.listRowBackground(Color.surface)
								}
							}
							Text("＋ Cadastrar lugar novo…").tag("__new")
						}
						.onChange(of: s.placeId) { _, v in
							if v == "__new" { s.placeId = ""; newPlaceFor = NewPlace(stop: s.id) }
						}
						if s.placeId.isEmpty { TextField("O que é? (ex.: Salão do casamento)", text: $s.label) }
						Toggle("Tem horário", isOn: $s.useClock)
						if s.useClock {
							DatePicker("Horário", selection: Binding(
								get: { Self.clock(s.minutes) },
								set: { s.minutes = Self.minutes(of: $0) }
							), displayedComponents: .hourAndMinute)
							.environment(\.timeZone, TripTime.zone) // the times are Curitiba times, whatever the phone's zone
						} else {
							TextField("Quando (ex.: Ida e volta)", text: $s.text)
						}
						Picker("Como chegar", selection: $s.transport) {
							ForEach(RoteiroTransport.allCases) { Text($0.label).tag($0) }
						}
						TextField("Dicas, o que fazer lá…", text: $s.note, axis: .vertical).lineLimit(2...6)
						HStack {
							Button("↑ Subir") { move(i, -1) }.disabled(i == 0)
							Spacer()
							Button("↓ Descer") { move(i, 1) }.disabled(i == stops.count - 1)
							Spacer()
							Button("✕ Remover", role: .destructive) { stops.remove(at: i) }
						}
						.buttonStyle(.borderless)
						.font(.text(14, .extraBold))
					}.listRowBackground(Color.surface)
				}
				Section {
					Button { add() } label: { Label { Text("Adicionar parada") } icon: { Icon(.pin, size: 18) } }
					Text("Com horário, o app avisa 30 min antes. A rota no mapa segue a ordem das paradas.")
						.font(.text(13)).foregroundStyle(Color.muted)
				}.listRowBackground(Color.surface)
				if let error { Section { Text(error).foregroundStyle(Color.danger).font(.text(14, .bold)) }.listRowBackground(Color.surface) }
				if day != nil { Section { Button("Apagar dia", role: .destructive) { confirmDelete = true } }.listRowBackground(Color.surface) }
			}
			.scrollContentBackground(.hidden)
			.background(Color.bg)
			.navigationTitle(day == nil ? "Novo dia" : "Editar dia")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) { Button(busy ? "Salvando…" : "Salvar") { Task { await save() } }.disabled(busy) }
			}
			.confirmationDialog("Apagar este dia do roteiro para todo mundo?", isPresented: $confirmDelete, titleVisibility: .visible) {
				Button("Apagar", role: .destructive) { Task { await remove() } }
			}
			.sheet(item: $newPlaceFor) { req in
				PlaceEditor(place: nil, changed: placesChanged, created: { id in
					if let i = stops.firstIndex(where: { $0.id == req.stop }) { stops[i].placeId = id }
				})
			}
			.onAppear(perform: fill)
		}
		.tint(.sea)
	}

	private static func clock(_ minutes: Int) -> Date {
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TripTime.zone
		return cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
	}

	private static func minutes(of d: Date) -> Int {
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TripTime.zone
		let c = cal.dateComponents([.hour, .minute], from: d)
		return (c.hour ?? 0) * 60 + (c.minute ?? 0)
	}

	private func fill() {
		guard !loaded else { return }
		loaded = true
		let dateKey = day?.date ?? suggestedDate
		date = TripTime.date("\(dateKey)T12:00:00.000-03:00") ?? Date()
		guard let d = day else { return }
		title = d.title
		who = d.who
		lead = d.lead
		wedding = d.wedding
		stops = d.stops.map { s in
			let m = Roteiro.minutes(s.time)
			return EditStop(stopId: s.id, useClock: m != nil || s.time.isEmpty, minutes: m ?? 10 * 60, text: m == nil ? s.time : "",
							placeId: s.placeId ?? "", label: s.label, transport: .of(s.transport), note: s.note)
		}
	}

	private func add() {
		stops.append(EditStop(stopId: nil, useClock: true, minutes: (stops.last.map { $0.minutes + 120 } ?? 10 * 60) % (24 * 60), text: "",
							  placeId: "", label: "", transport: stops.isEmpty ? .pe : .uber, note: ""))
	}

	private func move(_ i: Int, _ by: Int) {
		let j = i + by
		guard stops.indices.contains(i), stops.indices.contains(j) else { return }
		stops.swapAt(i, j)
	}

	private func save() async {
		let key = day?.date ?? TripTime.dayKey(date.formatted(.iso8601))
		if day == nil, takenDates.contains(key) {
			error = "Esse dia já existe no roteiro. Escolha outra data ou edite o dia."
			return
		}
		busy = true
		error = nil
		defer { busy = false }
		let body = DayBody(title: title, who: who, lead: lead, wedding: wedding, stops: stops.map { s in
			DayBody.Stop(id: s.stopId, time: s.useClock ? Roteiro.timeText(s.minutes) : s.text.trimmingCharacters(in: .whitespaces),
						 placeId: s.placeId.isEmpty ? nil : s.placeId, label: s.placeId.isEmpty ? s.label : "",
						 transport: s.transport.rawValue, note: s.note)
		})
		do {
			let _: OK = try await API.shared.put("/api/roteiro/days/\(key)", body)
			Roteiro.itineraryChanged()
			saved(key)
			dismiss()
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}

	private func remove() async {
		guard let d = day else { return }
		busy = true
		defer { busy = false }
		do {
			try await API.shared.delete("/api/roteiro/days/\(d.date)")
			Roteiro.itineraryChanged()
			saved(nil)
			dismiss()
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}
}

/// "Cadastrar lugar novo" from a stop: which stop gets the new place.
private struct NewPlace: Identifiable {
	let id = UUID()
	let stop: UUID
}
