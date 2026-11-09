import CryptoKit
import Foundation
import Nuke

/// Photos and videos come from presigned R2 links whose signature changes every day (at midnight UTC),
/// but the file behind a path never changes. Caches are keyed by the path, so nothing is downloaded twice.
enum MediaCache {
	/// The link without its signature.
	static func stableKey(_ url: URL) -> String {
		var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
		c?.query = nil
		return c?.string ?? url.absoluteString
	}

	/// Called once at launch, before any image loads: an on-disk cache (up to 400 MB) that ignores the
	/// changing signatures, instead of the default HTTP cache keyed by the whole link.
	@MainActor static func setUp() {
		ImagePipeline.shared = ImagePipeline(configuration: .withDataCache(name: "com.nelsul.curitibatrip.media", sizeLimit: 400 * 1024 * 1024))
	}

	static func imageRequest(_ url: URL?) -> ImageRequest? {
		url.map { ImageRequest(url: $0, userInfo: [.imageIdKey: stableKey($0)]) }
	}
}

/// Videos already watched play from the phone. A copy is saved while one plays on Wi-Fi (never on mobile
/// data, which would download it twice); up to 500 MB, the least recently watched go first.
@MainActor
final class VideoCache {
	static let shared = VideoCache()
	private let dir: URL
	private var saving: Set<String> = []

	private init() {
		dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "videos", directoryHint: .isDirectory)
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
	}

	/// The local copy when there is one, else the link (and a copy starts downloading on Wi-Fi).
	func playable(_ url: URL) -> URL {
		guard url.scheme == "https" || url.scheme == "http" else { return url }
		let name = SHA256.hash(data: Data(MediaCache.stableKey(url).utf8)).map { String(format: "%02x", $0) }.joined() + ".mp4"
		let file = dir.appending(path: name)
		if FileManager.default.fileExists(atPath: file.path) {
			try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
			return file
		}
		if UploadNetwork.shared.onWifi, !saving.contains(name) { save(url, to: file, name: name) }
		return url
	}

	private func save(_ url: URL, to file: URL, name: String) {
		saving.insert(name)
		let dir = dir
		Task.detached(priority: .utility) {
			var req = URLRequest(url: url)
			req.allowsCellularAccess = false
			req.allowsExpensiveNetworkAccess = false
			if let (tmp, resp) = try? await URLSession.shared.download(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 {
				try? FileManager.default.moveItem(at: tmp, to: file)
				VideoCache.prune(dir)
			}
			await MainActor.run { _ = VideoCache.shared.saving.remove(name) }
		}
	}

	nonisolated private static func prune(_ dir: URL, limit: Int = 500 * 1024 * 1024) {
		let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
		guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys) else { return }
		let entries = files.compactMap { f -> (URL, Int, Date)? in
			guard let v = try? f.resourceValues(forKeys: Set(keys)) else { return nil }
			return (f, v.fileSize ?? 0, v.contentModificationDate ?? .distantPast)
		}.sorted { $0.2 > $1.2 }
		var total = 0
		for (f, size, _) in entries {
			total += size
			if total > limit { try? FileManager.default.removeItem(at: f) }
		}
	}
}
