import SwiftUI

/// Top bar + the screen for the selected tab + the floating dock.
struct ShellView: View {
	@State private var tab: Tab = .diario
	/// The dock steps aside while the keyboard is up, so text fields (comments, captions) stay visible.
	@State private var keyboardUp = false
	@Environment(AppState.self) private var app
	@Bindable private var notifier = Notifier.shared

	var body: some View {
		VStack(spacing: 0) {
			TopBar(sending: tab == .enviar) { tab = .enviar }
			ZStack {
				// each tab keeps its own navigation stack (detail pages push inside it)
				switch tab {
				case .diario: Stacked(open: $notifier.openRoute) { FeedView() }
				case .mapa: Stacked { MapaView() }
				case .galeria: Stacked { GaleriaView() }
				case .enviar: Stacked { EnviarView() }
				case .roteiro: Stacked { RoteiroView() }
				case .mais: Stacked { MoreView() }
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.safeAreaInset(edge: .bottom, spacing: 0) {
			if !keyboardUp { Dock(selection: $tab).padding(.bottom, 4).transition(.move(edge: .bottom).combined(with: .opacity)) }
		}
		.animation(.easeOut(duration: 0.2), value: keyboardUp)
		// pick up uploads iOS kept sending while the app was closed, and refresh the feed as files arrive
		.task {
			Uploader.shared.start()
			LocationSharing.shared.restore()
			await Notifier.shared.start()
		}
		// a tapped notification: open the post, or the map's check-in
		.onChange(of: notifier.openRoute) { _, r in if r != nil { tab = .diario } }
		.onChange(of: notifier.openCheckin) { _, on in if on { tab = .mapa } }
		.onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
			Notifier.shared.markSeen() // what's in the app now was seen; only newer things notify
			Notifier.shared.scheduleRefresh()
			LocationSharing.shared.pause()
		}
		.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in LocationSharing.shared.resume() }
		.onChange(of: Uploader.shared.arrivals) { app.feedChanged() }
		.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
		.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
	}
}

/// A navigation stack that knows how to open photo/video and check-in pages.
struct Stacked<Content: View>: View {
	/// Set from outside (a tapped notification) to push a page.
	var open: Binding<Route?> = .constant(nil)
	@ViewBuilder let content: () -> Content

	var body: some View {
		NavigationStack {
			content()
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.background(DottedBackground()) // a NavigationStack paints its own opaque background otherwise
				.toolbar(.hidden, for: .navigationBar)
				// the dock floats over the stacks (they don't get its safe-area inset): keep the end of every list above it
				.contentMargins(.bottom, 104, for: .scrollContent)
				.navigationDestination(item: open) { route in
					Group {
						switch route {
						case .media(let id): MediaDetailView(id: id)
						case .checkin(let id): CheckinDetailView(id: id)
						}
					}
					.contentMargins(.bottom, 104, for: .scrollContent)
				}
				.navigationDestination(for: Route.self) { route in
					Group {
						switch route {
						case .media(let id): MediaDetailView(id: id)
						case .checkin(let id): CheckinDetailView(id: id)
						}
					}
					.contentMargins(.bottom, 104, for: .scrollContent)
				}
		}
		.tint(.ink)
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


extension View {
	/// Horizontal scrollers inside a tab must not get the stacks' bottom dock margin (it would push their content up).
	func noDockMargin() -> some View { contentMargins(.bottom, 0, for: .scrollContent) }
}
