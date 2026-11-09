import CoreLocation
import SwiftUI

/// New or existing stay (web StayEditor), admins only: type, where it is (search or map), name, address,
/// check-in and check-out, who stays there, booking link and notes.
struct StayEditor: View {
	/// nil = new stay
	let stay: RoteiroStay?
	/// the trip's first and last day: suggested check-in and check-out for a new stay
	let firstDay: String
	let lastDay: String
	/// After a save or delete, so the Roteiro reloads.
	let changed: () -> Void

	@Environment(AppState.self) private var app
	@Environment(\.dismiss) private var dismiss
	@State private var name = ""
	@State private var kind = "airbnb"
	@State private var coordinate: CLLocationCoordinate2D?
	@State private var address = ""
	@State private var link = ""
	@State private var note = ""
	@State private var hasDates = true
	@State private var checkIn = Date()
	@State private var checkOut = Date()
	@State private var guests: Set<String> = []
	@State private var picking = false
	@State private var busy = false
	@State private var error: String?
	@State private var confirmDelete = false
	@State private var loaded = false

	private static let kinds = [("hotel", "🏨 Hotel"), ("airbnb", "🏠 Airbnb"), ("casa", "🏡 Casa")]

	var body: some View {
		NavigationStack {
			Form {
				Section {
					Picker("Tipo", selection: $kind) {
						ForEach(Self.kinds, id: \.0) { Text($0.1).tag($0.0) }
					}
					.pickerStyle(.segmented)
				}.listRowBackground(Color.surface)
				Section("Onde fica") {
					Button { picking = true } label: {
						HStack {
							Icon(.pin, size: 18).foregroundStyle(Color.coral)
							Text(coordinate == nil ? "Buscar ou marcar no mapa" : String(format: "%.5f, %.5f", coordinate!.latitude, coordinate!.longitude))
								.foregroundStyle(coordinate == nil ? Color.sea : Color.ink)
							Spacer()
							if coordinate != nil { Text("Mudar").foregroundStyle(Color.sea) }
						}
						.font(.text(16, .bold))
					}
				}.listRowBackground(Color.surface)
				Section("Nome") { TextField("Ex.: Airbnb do Batel", text: $name) }.listRowBackground(Color.surface)
				Section("Endereço") { TextField("Rua, número, bairro", text: $address) }.listRowBackground(Color.surface)
				Section {
					Toggle("Com datas", isOn: $hasDates)
					if hasDates {
						DatePicker("Chegada (1ª noite)", selection: $checkIn, displayedComponents: .date)
						DatePicker("Saída", selection: $checkOut, in: checkIn..., displayedComponents: .date)
					}
				} header: { Text("Datas") } footer: {
					Text("No dia da chegada o roteiro termina aqui; no dia da saída, começa aqui. Sem datas = a viagem toda.")
				}
				.listRowBackground(Color.surface)
				Section("Quem fica aqui (\(guests.count))") {
					ForEach(app.people) { p in
						Button { if guests.contains(p.id) { guests.remove(p.id) } else { guests.insert(p.id) } } label: {
							HStack(spacing: 10) {
								AvatarView(name: p.name, color: p.tint, photo: p.photo, size: 30)
								Text(p.name).font(.text(16, .bold)).foregroundStyle(Color.ink)
								Spacer()
								if guests.contains(p.id) { Icon(.check, size: 18).foregroundStyle(Color.leaf) }
							}
						}
						.accessibilityAddTraits(guests.contains(p.id) ? .isSelected : [])
					}
				}.listRowBackground(Color.surface)
				Section("Site / link da reserva") {
					TextField("https://", text: $link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
				}.listRowBackground(Color.surface)
				Section("Observações") {
					TextField("Check-in às 15h, código da porta…", text: $note, axis: .vertical).lineLimit(2...6)
				}.listRowBackground(Color.surface)
				if let error { Section { Text(error).foregroundStyle(Color.danger).font(.text(14, .bold)) }.listRowBackground(Color.surface) }
				if stay != nil {
					Section { Button("Apagar hospedagem", role: .destructive) { confirmDelete = true } }.listRowBackground(Color.surface)
				}
			}
			.scrollContentBackground(.hidden)
			.background(Color.bg)
			.navigationTitle(stay == nil ? "Nova hospedagem" : "Editar hospedagem")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) {
					Button(busy ? "Salvando…" : "Salvar") { Task { await save() } }.disabled(busy)
				}
			}
			.fullScreenCover(isPresented: $picking) {
				LocationPicker(start: coordinate ?? stay?.coordinate, save: { c in coordinate = c }, onPick: { r in
					if name.trimmingCharacters(in: .whitespaces).isEmpty { name = r.name }
					if address.trimmingCharacters(in: .whitespaces).isEmpty, !r.detail.isEmpty, r.detail != "Lugar da viagem" {
						address = r.detail.replacingOccurrences(of: " · ", with: ", ")
					}
				})
			}
			.confirmationDialog("Apagar \"\(stay?.name ?? "")\"? Quem estava lá fica sem hospedagem no roteiro.",
								isPresented: $confirmDelete, titleVisibility: .visible) {
				Button("Apagar", role: .destructive) { Task { await remove() } }
			}
			.onAppear(perform: fill)
		}
		.tint(.sea)
		.environment(\.timeZone, TripTime.zone)
	}

	// MARK: dates as "YYYY-MM-DD" in Curitiba time

	private static func key(_ d: Date) -> String {
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TripTime.zone
		let c = cal.dateComponents([.year, .month, .day], from: d)
		return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
	}

	private static func date(_ key: String) -> Date {
		TripTime.date("\(key)T12:00:00.000-03:00") ?? Date()
	}

	private func fill() {
		guard !loaded else { return }
		loaded = true
		checkIn = Self.date(firstDay)
		checkOut = Self.date(lastDay)
		guard let s = stay else { return }
		name = s.name
		kind = s.kind
		coordinate = s.coordinate
		address = s.address
		link = s.link
		note = s.note
		guests = Set(s.guests)
		hasDates = s.checkIn != nil || s.checkOut != nil
		if let i = s.checkIn { checkIn = Self.date(i) }
		if let o = s.checkOut { checkOut = Self.date(o) }
	}

	private func save() async {
		guard let c = coordinate else {
			error = "Marque a hospedagem no mapa (busque pelo endereço ou arraste o mapa)."
			return
		}
		busy = true
		error = nil
		defer { busy = false }
		let body = StayBody(name: name, kind: kind, lat: c.latitude, lng: c.longitude, address: address, link: link,
							checkIn: hasDates ? Self.key(checkIn) : nil, checkOut: hasDates ? Self.key(checkOut) : nil,
							note: note, guests: Array(guests))
		do {
			if let s = stay {
				let _: OK = try await API.shared.put("/api/admin/stays/\(s.id)", body)
			} else {
				let _: CreatedId = try await API.shared.post("/api/admin/stays", body)
			}
			changed()
			dismiss()
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}

	private func remove() async {
		guard let s = stay else { return }
		busy = true
		defer { busy = false }
		do {
			try await API.shared.delete("/api/admin/stays/\(s.id)")
			changed()
			dismiss()
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}
}

/// POST /api/admin/stays, PUT /api/admin/stays/:id (dates sent as null when there are none)
struct StayBody: Encodable, Sendable {
	var name: String
	var kind: String
	var lat: Double
	var lng: Double
	var address: String
	var link: String
	var checkIn: String?
	var checkOut: String?
	var note: String
	var guests: [String]

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(name, forKey: .name); try c.encode(kind, forKey: .kind)
		try c.encode(lat, forKey: .lat); try c.encode(lng, forKey: .lng)
		try c.encode(address, forKey: .address); try c.encode(link, forKey: .link)
		try c.encode(checkIn, forKey: .checkIn); try c.encode(checkOut, forKey: .checkOut)
		try c.encode(note, forKey: .note); try c.encode(guests, forKey: .guests)
	}
	private enum CodingKeys: String, CodingKey { case name, kind, lat, lng, address, link, checkIn, checkOut, note, guests }
}
