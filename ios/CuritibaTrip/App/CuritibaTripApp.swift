import SwiftUI

@main
struct CuritibaTripApp: App {
	@State private var app = AppState()

	var body: some Scene {
		WindowGroup {
			RootView()
				.environment(app)
				.preferredColorScheme(.dark)
				.tint(.sea)
				.task { await app.restore() }
		}
	}
}

struct RootView: View {
	@Environment(AppState.self) private var app

	var body: some View {
		ZStack {
			DottedBackground()
			switch app.phase {
			case .loading:
				ProgressView().tint(.sea)
			case .signedOut:
				LoginView().transition(.opacity)
			case .signedIn:
				ShellView().transition(.opacity)
			case .outdated(let v):
				VStack(spacing: 14) {
					TitleRow(icon: .plane, title: "Nova versão")
					Text("Este app precisa ser atualizado (versão \(v) ou mais nova). Fale com o Nelson para instalar de novo.")
						.font(.text(17)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
				}
				.card(padding: 22).padding(24)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: app.phase)
	}
}
