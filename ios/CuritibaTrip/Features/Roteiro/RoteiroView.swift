import SwiftUI

/// Roteiro (web /roteiro): day chips + a boarding-pass ticket per day, with Uber and Google Maps buttons.
struct RoteiroView: View {
	@Environment(\.openURL) private var openURL
	@State private var itinerary: Itinerary?
	@State private var selected: String?
	@State private var error: String?

	private var days: [Itinerary.Day] { itinerary?.days ?? [] }
	private var day: Itinerary.Day? { days.first { $0.date == selected } ?? days.first }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 14) {
				TitleRow(icon: .ticket, title: "Roteiro")
				if let error { EmptyState(text: error, retry: { Task { await load() } }) }
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 8) {
						ForEach(days) { d in
							Chip(selected: d.id == day?.id, dashed: true, tint: d.wedding ? .berry : nil, action: { withAnimation(.bounce) { selected = d.id } }) {
								VStack(spacing: 0) {
									Text(String(d.date.suffix(2))).font(.display(17))
									Text(weekday(d.date)).font(.text(11, .extraBold))
								}
								.padding(.vertical, 4)
							}
						}
					}
					.padding(.vertical, 6)
					.padding(.horizontal, 2)
				}
				if let day { ticket(day).id(day.id).transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity)) }
			}
			.padding(16)
			.frame(maxWidth: 640)
			.frame(maxWidth: .infinity)
		}
		.task { await load() }
	}

	@ViewBuilder private func ticket(_ d: Itinerary.Day) -> some View {
		let index = (days.firstIndex { $0.id == d.id } ?? 0) + 1
		VStack(spacing: 0) {
			HStack(alignment: .center, spacing: 12) {
				VStack(alignment: .leading, spacing: 2) {
					Text(d.wedding ? "DIA ESPECIAL" : "DIA \(index) DE \(days.count)").font(.text(12, .extraBold)).kerning(1.2).opacity(0.9)
					Text(d.title).font(.display(24))
				}
				Spacer()
				VStack(spacing: -2) {
					Text(String(d.date.suffix(2))).font(.display(26))
					Text("NOV").font(.text(11, .extraBold))
				}
				.frame(width: 64, height: 64)
				.overlay(Circle().strokeBorder(.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [5, 4])))
				.rotationEffect(.degrees(10))
			}
			.foregroundStyle(.white)
			.padding(16)
			.background(d.wedding ? Color.berry : Color.seaDark)

			Line().stroke(Color.line, style: StrokeStyle(lineWidth: 3, dash: [7, 5])).frame(height: 3).padding(.horizontal, 14)

			VStack(alignment: .leading, spacing: 10) {
				Label { Text(d.who) } icon: { Icon(.people, size: 16) }
					.font(.text(14, .bold)).foregroundStyle(Color.muted)
				Text(d.lead).font(.text(17)).foregroundStyle(Color.ink)
				ForEach(Array(d.stops.enumerated()), id: \.element.id) { i, s in stop(s).popIn(delay: 0.1 + Double(i) * 0.07) }
				if let route = d.routeUrl, !d.wedding {
					Button { openURL(route) } label: { Label { Text("Rota do dia no Google Maps") } icon: { Icon(.map, size: 20) } }
						.buttonStyle(.chunky(.sea, fullWidth: true))
				}
			}
			.padding(16)
		}
		.background(Color.surface)
		.clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
		.overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(d.wedding ? Color.berry : Color.line, lineWidth: 2.5))
		.background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.shadow).offset(y: 5))
	}

	private func stop(_ s: Itinerary.Stop) -> some View {
		HStack(alignment: .top, spacing: 10) {
			Text(s.time).font(.display(13)).foregroundStyle(Color.onSun)
				.frame(width: 58).padding(.vertical, 3)
				.background(RoundedRectangle(cornerRadius: 10).fill(Color.sun))
				.background(RoundedRectangle(cornerRadius: 10).fill(Color.sunDark).offset(y: 2))
				.padding(.top, 10)
			VStack(alignment: .leading, spacing: 6) {
				Text(s.title).font(.text(17, .extraBold)).foregroundStyle(Color.ink)
				Text(itinerary?.transport[s.transport]?.label ?? s.transport)
					.font(.text(13, .extraBold)).foregroundStyle(transportColor(s.transport))
					.padding(.horizontal, 10).padding(.vertical, 1)
					.overlay(Capsule().strokeBorder(transportColor(s.transport), lineWidth: 2))
				Text(s.note).font(.text(15)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
				if let p = s.place {
					if !p.hours.isEmpty { Text("Horário: \(p.hours)").font(.text(13)).foregroundStyle(Color.muted) }
					HStack(spacing: 8) {
						Button { openURL(p.uberUrl) } label: { Label { Text("Pedir Uber") } icon: { Icon(.car, size: 18) } }
							.buttonStyle(.chunky(.uber, small: true))
						Button { openURL(p.mapsUrl) } label: { Label { Text("Mapa") } icon: { Icon(.pin, size: 18) } }
							.buttonStyle(.chunky(.secondary, small: true))
					}
					.padding(.top, 4)
				}
			}
			.padding(12)
			.frame(maxWidth: .infinity, alignment: .leading)
			.card(padding: 0, radius: 18)
		}
	}

	private func transportColor(_ t: String) -> Color {
		switch t { case "onibus", "rodo": .sky; case "turismo": .leaf; case "uber": .plum; default: .coral }
	}

	private func weekday(_ date: String) -> String {
		guard let d = TripTime.date("\(date)T12:00:00.000-03:00") else { return "" }
		return d.formatted(Date.FormatStyle(locale: TripTime.locale, timeZone: TripTime.zone).weekday(.abbreviated)).replacingOccurrences(of: ".", with: "")
	}

	private func load() async {
		do {
			itinerary = try await API.shared.get("/api/itinerary")
			let today = TripTime.dayKey(Date().ISO8601Format())
			if selected == nil { selected = itinerary?.days.first { $0.date == today }?.date ?? itinerary?.days.first?.date }
			error = nil
		} catch { self.error = error.localizedDescription }
	}
}

private struct Line: Shape {
	func path(in rect: CGRect) -> Path {
		var p = Path()
		p.move(to: CGPoint(x: 0, y: rect.midY))
		p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
		return p
	}
}
