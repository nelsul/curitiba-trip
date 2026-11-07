import SwiftUI

/// Top bar + the screen for the selected tab + the floating dock.
struct ShellView: View {
	@State private var tab: Tab = .diario

	var body: some View {
		VStack(spacing: 0) {
			TopBar()
			ZStack {
				switch tab {
				case .diario: FeedView()
				case .mapa: ComingSoon(tab: .mapa, webPath: "/mapa")
				case .enviar: ComingSoon(tab: .enviar, webPath: "/enviar")
				case .roteiro: ComingSoon(tab: .roteiro, webPath: "/roteiro")
				case .mais: MoreView()
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.safeAreaInset(edge: .bottom, spacing: 0) { Dock(selection: $tab).padding(.bottom, 4) }
	}
}

/// Placeholder for screens still being built: explains it and links to the same page on the website.
struct ComingSoon: View {
	let tab: Tab
	let webPath: String
	@Environment(\.openURL) private var openURL

	var body: some View {
		VStack(spacing: 16) {
			TitleRow(icon: tab.icon, title: tab.label)
			Text("Esta tela ainda está sendo feita no app. Enquanto isso, ela funciona no site.")
				.font(.text(17)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
			Button { openURL(API.shared.base.appending(path: webPath)) } label: {
				Label { Text("Abrir no site") } icon: { Icon(.expand, size: 18) }
			}
			.buttonStyle(.chunky(.sea))
		}
		.card(padding: 22)
		.padding(20)
		.popIn()
	}
}

/// Mais (first version): who's signed in + sign out.
struct MoreView: View {
	@Environment(AppState.self) private var app
	@Environment(\.openURL) private var openURL

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				TitleRow(icon: .user, title: "Mais")
				if let me = app.me {
					HStack(spacing: 16) {
						AvatarView(name: me.name, color: me.tint, photo: me.photo, size: 72)
						VStack(alignment: .leading, spacing: 2) {
							Text(me.name).font(.display(24)).foregroundStyle(Color.ink)
							if me.isAdmin { Text("Administrador").font(.text(14)).foregroundStyle(Color.muted) }
						}
						Spacer()
					}
					.card()
				}
				if app.me?.isAdmin == true {
					Button { openURL(API.shared.base.appending(path: "/admin")) } label: { Text("Gerenciar pessoas (site)") }
						.buttonStyle(.chunky(.secondary, fullWidth: true))
				}
				Button { Task { await app.signOut() } } label: { Text("Sair") }
					.buttonStyle(.chunky(.secondary, fullWidth: true))
			}
			.padding(16)
		}
	}
}
