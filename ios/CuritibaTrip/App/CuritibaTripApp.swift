import SwiftUI
import UserNotifications

@main
struct CuritibaTripApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
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

/// iOS wakes the app when background uploads finish; the uploader reconnects and calls the handler when done.
final class AppDelegate: NSObject, UIApplicationDelegate {
	func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
		MainActor.assumeIsolated {
			MediaCache.setUp()
			// must be registered before launch finishes
			Notifier.registerBackgroundTask()
			UNUserNotificationCenter.current().delegate = Notifier.shared
			// also runs when iOS relaunches the app in the background for a location event
			LocationSharing.shared.restore()
		}
		return true
	}

	func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
		guard identifier == Uploader.sessionId else { return completionHandler() }
		MainActor.assumeIsolated {
			Uploader.shared.backgroundCompletion = completionHandler
			Uploader.shared.start()
		}
	}
}
