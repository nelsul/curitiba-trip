import Foundation
import Observation

/// Pages through GET /api/feed (newest first, carousels already grouped by the server).
@MainActor @Observable
final class FeedModel {
	var posts: [Post] = []
	var loading = false
	var error: String?
	/// Filters (nil = all), the same as the web Diário.
	var day: String?
	var person: String?
	/// Every day that has posts, from the server.
	var postDays: [String] = []
	/// The trip days plus any other day with posts, for the day chips.
	var days: [String] { Array(Set(TripTime.tripDays + postDays)).sorted() }
	private var cursor: String?
	private var reachedEnd = false

	func refresh(app: AppState) async {
		cursor = nil
		reachedEnd = false
		await load(app: app, replace: true)
	}

	func loadMoreIfNeeded(after post: Post, app: AppState) async {
		guard !reachedEnd, !loading, post.id == posts.last?.id else { return }
		await load(app: app, replace: false)
	}

	private func load(app: AppState, replace: Bool) async {
		loading = true
		defer { loading = false }
		do {
			let page: FeedPage = try await API.shared.get("/api/feed", query: ["limit": "20", "before": replace ? nil : cursor, "day": day, "person": person])
			if let d = page.days { postDays = d }
			posts = replace ? page.posts : posts + page.posts.filter { p in !posts.contains { $0.id == p.id } }
			cursor = page.nextCursor
			reachedEnd = page.nextCursor == nil
			error = nil
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}
}
