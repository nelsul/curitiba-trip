import SwiftUI

/// A place's own page (web /roteiro/lugar/:id): photos, how to get there, hours, price, about, the days it's in
/// (with that day's forecast).
struct PlaceDetailView: View {
	let place: RoteiroPlace
	let days: [RoteiroDay]
	@Environment(\.openURL) private var openURL
	@State private var photo = 0
	@State private var full: URL?
	private var weather: WeatherStore { .shared }

	private var stops: [(RoteiroDay, RoteiroStop)] { days.flatMap { d in d.stops.filter { $0.placeId == place.id }.map { (d, $0) } } }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 14) {
				BackButton()
				ZStack(alignment: .topLeading) {
					if place.photos.isEmpty {
						VStack(spacing: 6) { Icon(.camera, size: 34); Text("Sem fotos ainda").font(.text(15, .extraBold)) }
							.foregroundStyle(Color.muted).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.surface2)
					} else {
						TabView(selection: $photo) {
							ForEach(Array(place.photos.enumerated()), id: \.element.id) { i, ph in
								Button { full = ph.url } label: { RemoteImage(url: ph.url) }.buttonStyle(.plain).tag(i)
									.accessibilityLabel("Foto \(i + 1) de \(place.photos.count), ver em tela cheia")
							}
						}
						.tabViewStyle(.page(indexDisplayMode: place.photos.count > 1 ? .always : .never))
					}
					Text(place.categoryInfo.label).font(.text(12, .extraBold)).foregroundStyle(.white)
						.padding(.horizontal, 10).padding(.vertical, 2).background(Capsule().fill(place.categoryInfo.color)).padding(10)
						.allowsHitTesting(false)
				}
				.aspectRatio(4 / 3, contentMode: .fit)
				.clipShape(RoundedRectangle(cornerRadius: 22))
				.overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.line, lineWidth: 2.5))

				Text(place.name).font(.display(30, relativeTo: .largeTitle)).foregroundStyle(Color.ink)
				if !place.address.isEmpty {
					Label { Text(place.address) } icon: { Icon(.pin, size: 16) }.font(.text(15)).foregroundStyle(Color.muted)
				}
				HStack(spacing: 8) {
					Button { openURL(place.uberURL) } label: { Label { Text("Pedir Uber") } icon: { Icon(.car, size: 18) } }.buttonStyle(.chunky(.uber, small: true))
					Button { openURL(place.mapsURL) } label: { Label { Text("Google Maps") } icon: { Icon(.map, size: 18) } }.buttonStyle(.chunky(.secondary, small: true))
					if let url = place.linkURL {
						Button { openURL(url) } label: { Icon(.external, size: 18) }.buttonStyle(.chunky(.secondary, small: true)).accessibilityLabel("Site ou Instagram")
					}
				}
				VStack(alignment: .leading, spacing: 12) {
					if !place.hours.isEmpty { fact(.clock, "Horário", place.hours) }
					if !place.price.isEmpty || place.priceLevel != nil { fact(.wallet, "Preço", "\(Roteiro.priceSigns(place.priceLevel)) \(place.price)") }
					if place.hours.isEmpty && place.price.isEmpty && place.priceLevel == nil {
						Text("Sem horário ou preço anotados.").font(.text(15)).foregroundStyle(Color.muted)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.card()
				if !place.description.isEmpty {
					Text("Sobre").font(.display(21)).foregroundStyle(Color.ink)
					Text(place.description).font(.text(16)).foregroundStyle(Color.ink).lineSpacing(3)
				}
				Text("No roteiro").font(.display(21)).foregroundStyle(Color.ink)
				if stops.isEmpty { Text("Ainda não está em nenhum dia.").font(.text(15)).foregroundStyle(Color.muted) }
				ForEach(stops, id: \.1.id) { d, s in
					VStack(alignment: .leading, spacing: 6) {
						HStack {
							Text(TripTime.longDay(d.date)).font(.display(17)).foregroundStyle(Color.ink)
							Spacer()
							if s.visitedAt != nil {
								Label { Text("Fomos!") } icon: { Icon(.check, size: 13) }.font(.text(12, .extraBold)).foregroundStyle(Color.onLeaf)
									.padding(.horizontal, 10).padding(.vertical, 2).background(Capsule().fill(Color.leaf))
							}
						}
						Text([d.title, s.time, RoteiroTransport.of(s.transport).label].filter { !$0.isEmpty }.joined(separator: " · "))
							.font(.text(14)).foregroundStyle(Color.muted)
						if !s.note.isEmpty { Text(s.note).font(.text(14)).foregroundStyle(Color.ink) }
						if let w = weather.days[d.date] { WeatherCard(day: w) }
					}
					.card()
				}
			}
			.padding(16)
			.frame(maxWidth: 640)
			.frame(maxWidth: .infinity)
		}
		.toolbar(.hidden, for: .navigationBar)
		.background(DottedBackground())
		.task { await weather.load() }
		.fullScreenCover(item: Binding(get: { full.map(FullPhoto.init) }, set: { full = $0?.url })) { f in
			ZStack(alignment: .topTrailing) {
				Color.black.ignoresSafeArea()
				RemoteImage(url: f.url, contentMode: .fit)
				Button { full = nil } label: { Icon(.close, size: 20).foregroundStyle(.white).frame(width: 44, height: 44).background(Circle().fill(.black.opacity(0.45))) }
					.padding(12).accessibilityLabel("Fechar foto")
			}
		}
	}

	private func fact(_ icon: IconName, _ title: String, _ value: String) -> some View {
		HStack(alignment: .top, spacing: 12) {
			Icon(icon, size: 20).foregroundStyle(Color.sea).frame(width: 38, height: 38).background(RoundedRectangle(cornerRadius: 12).fill(Color.surface2))
			VStack(alignment: .leading, spacing: 2) {
				Text(title).font(.text(15, .extraBold)).foregroundStyle(Color.ink)
				Text(value).font(.text(15)).foregroundStyle(Color.ink)
			}
		}
	}
}

private struct FullPhoto: Identifiable { let url: URL; var id: URL { url } }
