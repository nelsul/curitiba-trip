import CoreLocation
import PhotosUI
import SwiftUI

/// New or existing place (web PlaceEditor): type, where it is (search or map), name, address, hours, price,
/// description, link and photos. Everyone can edit the shared places.
struct PlaceEditor: View {
	/// nil = new place
	let place: RoteiroPlace?
	/// After any change (save, photo, delete), so the Roteiro reloads.
	let changed: () -> Void
	/// A new place was created (the day editor puts it in the stop).
	var created: ((String) -> Void)? = nil

	@Environment(AppState.self) private var app
	@Environment(\.dismiss) private var dismiss
	@State private var name = ""
	@State private var category = RoteiroCategory.comer
	@State private var coordinate: CLLocationCoordinate2D?
	@State private var address = ""
	@State private var hours = ""
	@State private var price = ""
	@State private var priceLevel: Int? = nil
	@State private var description = ""
	@State private var link = ""
	@State private var photos: [PlacePhoto] = []
	@State private var picked: [PhotosPickerItem] = []
	/// photos chosen before a new place exists: sent right after it's created
	@State private var pending: [Data] = []
	@State private var uploading = 0
	@State private var picking = false
	@State private var busy = false
	@State private var error: String?
	@State private var confirmDelete = false
	@State private var loaded = false

	var body: some View {
		NavigationStack {
			Form {
				Section {
					Picker("Tipo", selection: $category) {
						ForEach(RoteiroCategory.allCases) { Text($0.label).tag($0) }
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
				Section("Nome") { TextField("Ex.: Bar do Alemão", text: $name) }.listRowBackground(Color.surface)
				Section("Endereço") { TextField("Rua, bairro", text: $address) }.listRowBackground(Color.surface)
				Section("Horário de funcionamento") { TextField("Ex.: ter–sáb 11h–23h; fecha seg", text: $hours, axis: .vertical) }.listRowBackground(Color.surface)
				Section("Preço") {
					Picker("Faixa de preço", selection: $priceLevel) {
						Text("Não sei").tag(Int?.none)
						Text("Grátis").tag(Int?.some(0))
						Text("$ (barato)").tag(Int?.some(1))
						Text("$$").tag(Int?.some(2))
						Text("$$$").tag(Int?.some(3))
						Text("$$$$ (caro)").tag(Int?.some(4))
					}
					TextField("R$ 60–90 por pessoa", text: $price)
				}.listRowBackground(Color.surface)
				Section("Sobre") { TextField("O que pedir, dicas, reservas…", text: $description, axis: .vertical).lineLimit(3...8) }.listRowBackground(Color.surface)
				Section("Site ou Instagram") {
					TextField("https://", text: $link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
				}.listRowBackground(Color.surface)
				Section("Fotos") {
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 8) {
							ForEach(photos) { ph in
								RemoteImage(url: ph.url)
									.frame(width: 88, height: 88)
									.clipShape(RoundedRectangle(cornerRadius: 12))
									.overlay(alignment: .topTrailing) {
										Button { Task { await removePhoto(ph) } } label: {
											Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(.white, .black.opacity(0.6))
										}
										.buttonStyle(.plain).padding(4)
										.accessibilityLabel("Apagar foto")
									}
							}
							ForEach(Array(pending.enumerated()), id: \.offset) { _, data in
								if let img = UIImage(data: data) {
									Image(uiImage: img).resizable().scaledToFill().frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: 12))
								}
							}
							ForEach(0..<uploading, id: \.self) { _ in
								ProgressView().frame(width: 88, height: 88).background(RoundedRectangle(cornerRadius: 12).fill(Color.surface2))
							}
							PhotosPicker(selection: $picked, maxSelectionCount: 10, matching: .images) {
								VStack(spacing: 4) { Icon(.camera, size: 24); Text("Adicionar").font(.text(12, .extraBold)) }
									.foregroundStyle(Color.muted)
									.frame(width: 88, height: 88)
									.overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.line, style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
							}
						}
						.padding(.vertical, 4)
					}
				}.listRowBackground(Color.surface)
				if let error { Section { Text(error).foregroundStyle(Color.danger).font(.text(14, .bold)) }.listRowBackground(Color.surface) }
				if place != nil {
					Section { Button("Apagar lugar", role: .destructive) { confirmDelete = true } }.listRowBackground(Color.surface)
				}
			}
			.scrollContentBackground(.hidden)
			.background(Color.bg)
			.navigationTitle(place == nil ? "Novo lugar" : "Editar lugar")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) {
					Button(busy ? "Salvando…" : "Salvar") { Task { await save() } }.disabled(busy || uploading > 0)
				}
			}
			.fullScreenCover(isPresented: $picking) {
				LocationPicker(start: coordinate ?? place?.coordinate, save: { c in coordinate = c }, onPick: { r in
					if name.trimmingCharacters(in: .whitespaces).isEmpty { name = r.name }
					if address.trimmingCharacters(in: .whitespaces).isEmpty, !r.detail.isEmpty, r.detail != "Lugar da viagem" {
						address = r.detail.replacingOccurrences(of: " · ", with: ", ")
					}
				})
			}
			.confirmationDialog("Apagar \"\(place?.name ?? "")\" para todo mundo? Se estiver no roteiro, a parada fica só com o nome.",
								isPresented: $confirmDelete, titleVisibility: .visible) {
				Button("Apagar", role: .destructive) { Task { await remove() } }
			}
			.onChange(of: picked) { _, items in
				guard !items.isEmpty else { return }
				picked = []
				Task { await add(items) }
			}
			.onAppear(perform: fill)
		}
		.tint(.sea)
	}

	private func fill() {
		guard !loaded else { return }
		loaded = true
		guard let p = place else { return }
		name = p.name
		category = p.categoryInfo
		coordinate = p.coordinate
		address = p.address
		hours = p.hours
		price = p.price
		priceLevel = p.priceLevel
		description = p.description
		link = p.link
		photos = p.photos
	}

	/// Photos are shrunk to 1600 px JPEG on the phone before sending (fast uploads, still sharp).
	private func add(_ items: [PhotosPickerItem]) async {
		var datas: [Data] = []
		for item in items {
			if let raw = try? await item.loadTransferable(type: Data.self), let jpeg = Self.shrink(raw) { datas.append(jpeg) }
		}
		if let p = place { await upload(datas, to: p.id) } else { pending += datas }
	}

	nonisolated static func shrink(_ data: Data, max: CGFloat = 1600) -> Data? {
		guard let img = UIImage(data: data) else { return nil }
		let scale = min(1, max / Swift.max(img.size.width, img.size.height))
		let size = CGSize(width: (img.size.width * scale).rounded(), height: (img.size.height * scale).rounded())
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		let out = UIGraphicsImageRenderer(size: size, format: format).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
		return out.jpegData(compressionQuality: 0.85)
	}

	private func upload(_ datas: [Data], to id: String) async {
		error = nil
		uploading += datas.count
		for d in datas {
			do {
				let ph: PlacePhoto = try await API.shared.put("/api/roteiro/places/\(id)/photos", data: d, contentType: "image/jpeg", method: "POST")
				photos.append(ph)
			} catch {
				app.handle(error)
				self.error = error.localizedDescription
			}
			uploading -= 1
		}
		changed()
	}

	private func removePhoto(_ ph: PlacePhoto) async {
		guard let p = place else { return }
		do {
			try await API.shared.delete("/api/roteiro/places/\(p.id)/photos/\(ph.id)")
			photos.removeAll { $0.id == ph.id }
			changed()
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}

	private func save() async {
		guard let c = coordinate else {
			error = "Marque o lugar no mapa (busque pelo nome ou arraste o mapa)."
			return
		}
		busy = true
		error = nil
		defer { busy = false }
		let body = PlaceBody(name: name, category: category.rawValue, lat: c.latitude, lng: c.longitude, address: address, hours: hours,
							 price: price, priceLevel: priceLevel, description: description, link: link)
		do {
			if let p = place {
				let _: OK = try await API.shared.patch("/api/roteiro/places/\(p.id)", body)
			} else {
				let made: CreatedId = try await API.shared.post("/api/roteiro/places", body)
				created?(made.id)
				if !pending.isEmpty { await upload(pending, to: made.id) }
			}
			changed()
			if error == nil { dismiss() }
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}

	private func remove() async {
		guard let p = place else { return }
		busy = true
		defer { busy = false }
		do {
			try await API.shared.delete("/api/roteiro/places/\(p.id)")
			changed()
			dismiss()
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}
}
