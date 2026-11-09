import SwiftUI

/// Countdown to the wedding at the top of the Diário; afterwards, the way into the Retrospectiva.
struct CountdownCard: View {
	var big = false

	var body: some View {
		TimelineView(.periodic(from: .now, by: 1)) { ctx in
			let left = max(0, Wedding.at.timeIntervalSince(ctx.date))
			HStack(spacing: left > 0 ? 18 : 12) {
				Icon(left > 0 ? .ring : .sparkle, size: big ? 40 : 28)
					.foregroundStyle(left > 0 ? .white : Color.onSun)
					.frame(width: big ? 72 : 52, height: big ? 72 : 52)
					.background(RoundedRectangle(cornerRadius: 16).fill(left > 0 ? Color.berry : Color.sun))
				if left > 0 {
					VStack(alignment: .center, spacing: 6) {
						Text("Contagem para o casamento").font(.text(13, .extraBold)).foregroundStyle(Color.berry)
						HStack(spacing: 16) {
							part(Int(left) / 86_400, "dias")
							part(Int(left) / 3600 % 24, "horas")
							part(Int(left) / 60 % 60, "min")
							part(Int(left) % 60, "seg")
						}
					}
					.accessibilityElement(children: .ignore)
					.accessibilityLabel("Faltam \(Int(left) / 86_400) dias e \(Int(left) / 3600 % 24) horas para o casamento")
				} else {
					VStack(alignment: .leading, spacing: 2) {
						Text("Retrospectiva da viagem").font(.display(19)).foregroundStyle(Color.ink)
						Text("Os melhores momentos, escolhidos a dedo. Toque para ver.").font(.text(14)).foregroundStyle(Color.ink)
					}
				}
				if left <= 0 { Spacer(minLength: 0) }
			}
			// counting: the ring and the numbers centered in the card
			.frame(maxWidth: .infinity)
			.padding(.vertical, 16).padding(.horizontal, 18)
			.background(RoundedRectangle(cornerRadius: 22).fill(LinearGradient(colors: [left > 0 ? Color.berry.opacity(0.3) : Color.sun.opacity(0.3), Color.surface], startPoint: .topLeading, endPoint: .bottomTrailing)))
			.background(RoundedRectangle(cornerRadius: 22).fill(Color.surface))
			.overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.berry.opacity(0.6), lineWidth: 2.5))
		}
	}

	private func part(_ n: Int, _ label: String) -> some View {
		VStack(spacing: 2) {
			Text(String(format: "%02d", n)).font(.display(big ? 40 : 29)).monospacedDigit().foregroundStyle(Color.ink)
			Text(label).font(.text(11, .extraBold)).foregroundStyle(Color.muted).padding(.top, 2)
		}
	}
}
