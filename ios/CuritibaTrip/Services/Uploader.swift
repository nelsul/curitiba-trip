import Foundation
import Network
import Observation
import UIKit
import Photos
import UniformTypeIdentifiers
import os

/// One photo or video on its way to the diary. Saved to disk so uploads survive the app being closed.
struct UploadJob: Codable, Identifiable, Sendable {
	enum State: String, Codable, Sendable { case waiting, preparing, uploading, finishing, done, failed }

	let id: UUID
	let assetId: String
	var caption: String
	/// Only used when the photo itself has no location (the person chose "use my current location").
	var deviceLat: Double?
	var deviceLng: Double?

	var state: State = .waiting
	var name = ""
	var kind = "photo"
	var size: Int64 = 0
	var mediaId: String?
	var partSize: Int64 = 0
	var partCount = 0
	var urls: [Int: String] = [:]
	var etags: [Int: String] = [:]
	var attempts: [Int: Int] = [:]
	var error: String?
	var duplicate = false
	var hasLocation = false
	/// Send the original only on Wi-Fi (a low-res preview goes to the diary first). Optional: older saved jobs lack it.
	var wifiOnly: Bool?
	var previewSent: Bool?
	var waitsForWifi: Bool { wifiOnly == true }
}

/// "Enviar só no Wi-Fi" (Enviar screen) and whether the phone is on Wi-Fi right now.
@MainActor @Observable
final class UploadNetwork {
	static let shared = UploadNetwork()
	private static let key = "envio-so-wifi"
	var wifiOnly: Bool { didSet { UserDefaults.standard.set(wifiOnly, forKey: Self.key) } }
	private(set) var onWifi = true
	/// Debug builds: `FORCE_NO_WIFI=1` also holds "só no Wi-Fi" uploads in the app, so the waiting state can be tested.
	private(set) var simulatedNoWifi = false
	private let monitor = NWPathMonitor()

	private init() {
		wifiOnly = UserDefaults.standard.bool(forKey: Self.key)
		#if DEBUG
		// Simulator testing only: `SIMCTL_CHILD_FORCE_NO_WIFI=1` acts as if the phone were off Wi-Fi.
		let forceOff = ProcessInfo.processInfo.environment["FORCE_NO_WIFI"] == "1"
		#else
		let forceOff = false
		#endif
		simulatedNoWifi = forceOff
		monitor.pathUpdateHandler = { path in
			let wifi = !forceOff && path.status == .satisfied && !path.isExpensive && !path.usesInterfaceType(.cellular)
			Task { @MainActor in UploadNetwork.shared.onWifi = wifi }
		}
		monitor.start(queue: DispatchQueue(label: "upload-network"))
	}
}

/// Sends originals from the photo library to R2 with the multipart flow in web/API.md, using a background
/// `URLSession`: once a file's parts are queued, iOS keeps sending them even if the app is suspended or closed.
@MainActor @Observable
final class Uploader {
	static let shared = Uploader()
	static let sessionId = "com.nelsul.curitibatrip.uploads"
	private static let maxAttempts = 8
	/// How many files are prepared (exported + split) ahead of the ones being sent.
	private static let maxActive = 3

	private(set) var jobs: [UploadJob] = []
	/// Bytes in flight per job and part (not saved; recomputed from iOS's callbacks).
	private var inflight: [UUID: [Int: Int64]] = [:]
	/// Bumped when a file reaches the server, so the feed can refresh.
	private(set) var arrivals = 0
	/// Given by the system when it wakes the app for finished background transfers.
	var backgroundCompletion: (() -> Void)?

	private let log = Logger(subsystem: "com.nelsul.curitibatrip", category: "upload")
	private let delegate = SessionDelegate()
	@ObservationIgnored private lazy var session: URLSession = {
		let config = URLSessionConfiguration.background(withIdentifier: Self.sessionId)
		config.sessionSendsLaunchEvents = true
		config.isDiscretionary = false
		config.allowsCellularAccess = true
		config.httpMaximumConnectionsPerHost = 4
		return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
	}()
	private var pumping = false
	private var started = false

	private static let dir: URL = {
		let d = URL.applicationSupportDirectory.appending(path: "Uploads", directoryHint: .isDirectory)
		try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
		var v = d
		var rv = URLResourceValues()
		rv.isExcludedFromBackup = true
		try? v.setResourceValues(rv)
		return d
	}()
	private static let stateFile = dir.appending(path: "jobs.json")
	private func folder(_ job: UploadJob) -> URL { Self.dir.appending(path: job.id.uuidString, directoryHint: .isDirectory) }
	private func partFile(_ job: UploadJob, _ n: Int) -> URL { folder(job).appending(path: "part-\(n)") }

	private init() {
		if let data = try? Data(contentsOf: Self.stateFile), let saved = try? JSONDecoder().decode([UploadJob].self, from: data) {
			jobs = saved
		}
	}

	// MARK: - Public

	/// Re-attaches to transfers iOS kept running and restarts anything that was interrupted. Call on launch.
	func start() {
		guard !started else { return }
		started = true
		_ = session // creating it reconnects to the background session
		Task { await reconcile() }
	}

	func add(assetId: String, caption: String, deviceLocation: (Double, Double)?, wifiOnly: Bool = false) {
		// the same photo already queued or sent from this phone: the server would also refuse a copy
		if jobs.contains(where: { $0.assetId == assetId && $0.state != .failed }) { return }
		jobs.removeAll { $0.assetId == assetId }
		var job = UploadJob(id: UUID(), assetId: assetId, caption: caption, deviceLat: deviceLocation?.0, deviceLng: deviceLocation?.1)
		job.wifiOnly = wifiOnly ? true : nil
		jobs.append(job)
		save()
		pump()
	}

	func retry(_ id: UUID) {
		guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
		jobs[i].error = nil
		jobs[i].attempts = [:]
		if jobs[i].mediaId != nil, jobs[i].partCount > 0, FileManager.default.fileExists(atPath: folder(jobs[i]).path) {
			jobs[i].state = .uploading
			save()
			Task { await resumeParts(id) }
		} else {
			reset(i)
			pump()
		}
	}

	/// "Enviar agora": stop waiting for Wi-Fi and send this one over any connection.
	func sendNow(_ id: UUID) {
		guard let job = jobs.first(where: { $0.id == id }) else { return }
		update(id) { $0.wifiOnly = nil }
		guard job.state == .uploading else { return pump() }
		session.getAllTasks { tasks in
			for t in tasks where t.taskDescription?.hasPrefix(id.uuidString) == true { t.cancel() }
			Task { @MainActor in
				try? await Task.sleep(for: .milliseconds(300))
				await Uploader.shared.resumeParts(id)
			}
		}
	}

	func cancel(_ id: UUID) {
		guard let job = jobs.first(where: { $0.id == id }) else { return }
		jobs.removeAll { $0.id == id }
		inflight[id] = nil
		save()
		session.getAllTasks { tasks in
			for t in tasks where t.taskDescription?.hasPrefix(id.uuidString) == true { t.cancel() }
		}
		try? FileManager.default.removeItem(at: folder(job))
		if let mediaId = job.mediaId, job.state != .done {
			Task { try? await API.shared.delete("/api/uploads/\(mediaId)") }
		}
		pump()
	}

	func clearFinished() {
		jobs.removeAll { $0.state == .done }
		save()
	}

	/// Bytes sent so far for a job (finished parts + parts in flight).
	func sent(_ job: UploadJob) -> Int64 {
		if job.state == .done || job.state == .finishing { return job.size }
		let finished = job.etags.keys.reduce(Int64(0)) { $0 + partBytes(job, $1) }
		return finished + (inflight[job.id]?.values.reduce(0, +) ?? 0)
	}

	var isBusy: Bool { jobs.contains { [.waiting, .preparing, .uploading, .finishing].contains($0.state) } }

	// MARK: - Preparing

	/// Starts preparing waiting jobs, a few at a time.
	private func pump() {
		guard !pumping else { return }
		pumping = true
		Task {
			defer { pumping = false }
			while true {
				let active = jobs.filter { $0.state == .preparing || $0.state == .uploading }.count
				guard active < Self.maxActive, let next = jobs.first(where: { $0.state == .waiting }) else { break }
				await prepare(next.id)
			}
		}
	}

	private func update(_ id: UUID, _ change: (inout UploadJob) -> Void) {
		guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
		change(&jobs[i])
		save()
	}

	private func fail(_ id: UUID, _ message: String) {
		log.error("upload \(id) failed: \(message, privacy: .public)")
		update(id) { $0.state = .failed; $0.error = message }
		inflight[id] = nil
		pump()
	}

	private func reset(_ i: Int) {
		try? FileManager.default.removeItem(at: folder(jobs[i]))
		let j = jobs[i]
		jobs[i] = UploadJob(id: j.id, assetId: j.assetId, caption: j.caption, deviceLat: j.deviceLat, deviceLng: j.deviceLng)
		jobs[i].wifiOnly = j.wifiOnly
		save()
	}

	/// Copies the original out of the photo library, starts the upload on the server, splits it into parts and queues them.
	private func prepare(_ id: UUID) async {
		update(id) { $0.state = .preparing; $0.error = nil }
		guard let job = jobs.first(where: { $0.id == id }) else { return }
		guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [job.assetId], options: nil).firstObject else {
			return fail(id, "A foto não está mais na sua galeria.")
		}
		let resources = PHAssetResource.assetResources(for: asset)
		let isVideo = asset.mediaType == .video
		let preferred: [PHAssetResourceType] = isVideo ? [.fullSizeVideo, .video] : [.fullSizePhoto, .photo]
		guard let resource = preferred.lazy.compactMap({ t in resources.first { $0.type == t } }).first else {
			return fail(id, "Não foi possível ler o arquivo original.")
		}

		let dir = folder(job)
		try? FileManager.default.removeItem(at: dir)
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		let original = dir.appending(path: "original")
		do {
			try await export(resource, to: original)
		} catch {
			return fail(id, "Não foi possível copiar o original (está no iCloud? Tente com internet).")
		}
		let size = (try? FileManager.default.attributesOfItem(atPath: original.path)[.size] as? Int64) ?? 0
		guard size > 0 else { return fail(id, "Arquivo vazio.") }

		let type = UTType(resource.uniformTypeIdentifier)?.preferredMIMEType ?? (isVideo ? "video/quicktime" : "image/heic")
		let loc = asset.location?.coordinate
		let body = CreateUpload(
			name: resource.originalFilename,
			size: size,
			type: type,
			takenAt: asset.creationDate.map { $0.formatted(.iso8601) },
			takenAtSource: asset.creationDate == nil ? nil : "exif",
			lat: loc?.latitude ?? job.deviceLat,
			lng: loc?.longitude ?? job.deviceLng,
			locationSource: loc != nil ? "device-library" : (job.deviceLat != nil ? "device" : nil),
			caption: job.caption,
			clientAssetId: job.assetId
		)
		let created: UploadStart
		do {
			created = try await API.shared.post("/api/uploads", body)
		} catch {
			return fail(id, error.localizedDescription)
		}
		update(id) {
			$0.name = resource.originalFilename
			$0.kind = isVideo ? "video" : "photo"
			$0.size = size
			$0.mediaId = created.id
			$0.hasLocation = body.lat != nil
		}
		if created.duplicate == true {
			try? FileManager.default.removeItem(at: dir)
			update(id) { $0.state = .done; $0.duplicate = true }
			return
		}
		guard let partSize = created.partSize, let partCount = created.partCount, partCount > 0 else {
			return fail(id, "Resposta inesperada do servidor.")
		}
		// waiting for Wi-Fi: a low-res picture goes to the diary now, the original later
		if jobs.first(where: { $0.id == id })?.waitsForWifi == true, created.preview != true, !UploadNetwork.shared.onWifi {
			if let jpeg = await Self.previewJPEG(asset), let _: OK = try? await API.shared.put("/api/uploads/\(created.id)/preview", data: jpeg, contentType: "image/jpeg") {
				update(id) { $0.previewSent = true }
				arrivals += 1
			}
		}
		do {
			try await Self.split(original, partSize: partSize, partCount: partCount, into: dir)
		} catch {
			return fail(id, "Sem espaço no iPhone para preparar o envio.")
		}
		update(id) { $0.partSize = partSize; $0.partCount = partCount; $0.state = .uploading }
		await resumeParts(id)
	}

	/// A ~720 px JPEG of the photo (or the video's first frame) for the preview.
	nonisolated private static func previewJPEG(_ asset: PHAsset) async -> Data? {
		let options = PHImageRequestOptions()
		options.deliveryMode = .highQualityFormat
		options.isNetworkAccessAllowed = true
		options.resizeMode = .exact
		let image: UIImage? = await withCheckedContinuation { c in
			PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 720, height: 720), contentMode: .aspectFit, options: options) { img, _ in
				c.resume(returning: img)
			}
		}
		return image?.jpegData(compressionQuality: 0.7)
	}

	private func export(_ resource: PHAssetResource, to url: URL) async throws {
		let options = PHAssetResourceRequestOptions()
		options.isNetworkAccessAllowed = true
		try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
			PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
				if let error { c.resume(throwing: error) } else { c.resume() }
			}
		}
	}

	/// Background uploads need a file per request, so the original is cut into `part-N` files (one part = the file itself).
	/// Runs off the main thread (big videos take a moment).
	nonisolated private static func split(_ original: URL, partSize: Int64, partCount: Int, into dir: URL) async throws {
		if partCount == 1 {
			try FileManager.default.moveItem(at: original, to: dir.appending(path: "part-1"))
			return
		}
		let input = try FileHandle(forReadingFrom: original)
		defer { try? input.close() }
		for n in 1...partCount {
			let data = try input.read(upToCount: Int(partSize)) ?? Data()
			try data.write(to: dir.appending(path: "part-\(n)"))
		}
		try FileManager.default.removeItem(at: original)
	}

	// MARK: - Sending

	/// Queues every part that isn't sent or already in flight (fetching fresh links when needed).
	fileprivate func resumeParts(_ id: UUID) async {
		guard let job = jobs.first(where: { $0.id == id }), let mediaId = job.mediaId else { return }
		if job.waitsForWifi && UploadNetwork.shared.simulatedNoWifi { return }
		let running = await runningParts(id)
		let missing = (1...max(job.partCount, 1)).filter { job.etags[$0] == nil && !running.contains($0) }
		if missing.isEmpty {
			if job.etags.count == job.partCount { await finish(id) }
			return
		}
		let needUrls = missing.filter { job.urls[$0] == nil }
		do {
			for batch in stride(from: 0, to: needUrls.count, by: 50).map({ Array(needUrls[$0..<min($0 + 50, needUrls.count)]) }) {
				let r: PartURLs = try await API.shared.post("/api/uploads/\(mediaId)/parts", PartsBody(parts: batch))
				update(id) { j in for (k, v) in r.urls { if let n = Int(k) { j.urls[n] = v } } }
			}
		} catch {
			if (error as? APIError)?.status == 409 { return await finish(id) } // the server already has it
			return fail(id, error.localizedDescription)
		}
		for n in missing { queuePart(id, n) }
	}

	private func queuePart(_ id: UUID, _ n: Int, delay: TimeInterval = 0) {
		guard let job = jobs.first(where: { $0.id == id }), let raw = job.urls[n], let url = URL(string: raw) else { return }
		var req = URLRequest(url: url)
		req.httpMethod = "PUT"
		// "só no Wi-Fi": iOS holds the part (even with the app closed) until the phone is on Wi-Fi
		req.allowsCellularAccess = !job.waitsForWifi
		req.allowsExpensiveNetworkAccess = !job.waitsForWifi
		let task = session.uploadTask(with: req, fromFile: partFile(job, n))
		task.taskDescription = "\(id.uuidString)|\(n)"
		if delay > 0 { task.earliestBeginDate = Date().addingTimeInterval(delay) }
		task.countOfBytesClientExpectsToSend = partBytes(job, n)
		task.resume()
	}

	/// The "complete" call also goes through the background session (as an upload of a small JSON file),
	/// so a file can be finished while the app is asleep.
	private func finish(_ id: UUID, delay: TimeInterval = 0) async {
		guard let job = jobs.first(where: { $0.id == id }), let mediaId = job.mediaId else { return }
		update(id) { $0.state = .finishing }
		let body = CompleteBody(parts: job.etags.sorted { $0.key < $1.key }.map { .init(n: $0.key, etag: $0.value) })
		let file = folder(job).appending(path: "complete.json")
		do {
			try FileManager.default.createDirectory(at: folder(job), withIntermediateDirectories: true)
			try JSONEncoder().encode(body).write(to: file)
		} catch {
			return fail(id, "Sem espaço no iPhone.")
		}
		var req = API.shared.request("POST", "/api/uploads/\(mediaId)/complete")
		req.setValue("application/json", forHTTPHeaderField: "content-type")
		let task = session.uploadTask(with: req, fromFile: file)
		task.taskDescription = "\(id.uuidString)|complete"
		if delay > 0 { task.earliestBeginDate = Date().addingTimeInterval(delay) }
		task.resume()
	}

	private func runningParts(_ id: UUID) async -> Set<Int> {
		let tasks = await session.allTasks
		return Set(tasks.compactMap { t -> Int? in
			guard t.state == .running || t.state == .suspended, let d = t.taskDescription else { return nil }
			let p = d.split(separator: "|")
			return p.count == 2 && p[0] == id.uuidString ? Int(p[1]) : nil
		})
	}

	private func partBytes(_ job: UploadJob, _ n: Int) -> Int64 {
		guard job.partCount > 0 else { return 0 }
		return n < job.partCount ? job.partSize : job.size - job.partSize * Int64(job.partCount - 1)
	}

	/// After a relaunch: anything that was mid-way gets picked up again.
	private func reconcile() async {
		let tasks = await session.allTasks
		let live = Set(tasks.compactMap(\.taskDescription))
		for job in jobs {
			switch job.state {
			case .preparing:
				if let i = jobs.firstIndex(where: { $0.id == job.id }) { reset(i) }
			case .uploading:
				await resumeParts(job.id)
			case .finishing where !live.contains("\(job.id.uuidString)|complete"):
				await finish(job.id)
			default: break
			}
		}
		pump()
	}

	// MARK: - Callbacks from the background session

	fileprivate func progress(_ desc: String?, sent: Int64) {
		guard let (id, n) = parse(desc), let n else { return }
		inflight[id, default: [:]][n] = sent
	}

	fileprivate func completed(_ desc: String?, status: Int, etag: String?, failed: Bool) {
		guard let (id, part) = parse(desc), let job = jobs.first(where: { $0.id == id }) else { return }
		inflight[id]?[part ?? 0] = nil
		guard let n = part else { return completedFinish(job, status: status, failed: failed) }

		if !failed, (200..<300).contains(status), let etag {
			try? FileManager.default.removeItem(at: partFile(job, n))
			update(id) { $0.etags[n] = etag; $0.attempts[n] = nil }
			if let j = jobs.first(where: { $0.id == id }), j.etags.count == j.partCount, j.state == .uploading {
				Task { await finish(id) }
			}
			return
		}
		// failed part: retry with backoff; a 403 usually means the link expired
		let attempt = (job.attempts[n] ?? 0) + 1
		if attempt >= Self.maxAttempts { return fail(id, "Conexão instável. Toque em “Tentar de novo”.") }
		update(id) { j in
			j.attempts[n] = attempt
			if status == 403 || status == 400 { j.urls[n] = nil }
		}
		let delay = min(60, pow(2, Double(attempt)))
		if status == 403 || status == 400 {
			Task {
				try? await Task.sleep(for: .seconds(delay))
				await resumeParts(id)
			}
		} else {
			queuePart(id, n, delay: delay)
		}
	}

	private func completedFinish(_ job: UploadJob, status: Int, failed: Bool) {
		// 409 = the server already finished it (an earlier "complete" got through)
		if !failed, (200..<300).contains(status) || status == 409 {
			try? FileManager.default.removeItem(at: folder(job))
			update(job.id) { $0.state = .done; $0.urls = [:]; $0.attempts = [:] }
			inflight[job.id] = nil
			arrivals += 1
			pump()
			return
		}
		if status == 401 { return fail(job.id, "Sua sessão expirou. Entre de novo e toque em “Tentar de novo”.") }
		let attempt = (job.attempts[0] ?? 0) + 1
		if attempt >= Self.maxAttempts || (400..<500).contains(status) {
			return fail(job.id, "O servidor não aceitou o arquivo (\(status)).")
		}
		update(job.id) { $0.attempts[0] = attempt }
		Task { await finish(job.id, delay: min(60, pow(2, Double(attempt)))) }
	}

	fileprivate func eventsFinished() {
		backgroundCompletion?()
		backgroundCompletion = nil
	}

	private func parse(_ desc: String?) -> (UUID, Int?)? {
		guard let p = desc?.split(separator: "|"), p.count == 2, let id = UUID(uuidString: String(p[0])) else { return nil }
		return (id, p[1] == "complete" ? nil : Int(p[1]))
	}

	private func save() {
		do { try JSONEncoder().encode(jobs).write(to: Self.stateFile, options: .atomic) }
		catch { log.error("could not save uploads: \(error.localizedDescription, privacy: .public)") }
	}
}

/// Receives the background session's events (on its own queue) and hands them to the uploader on the main actor.
private final class SessionDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
	func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData _: Int64, totalBytesSent: Int64, totalBytesExpectedToSend _: Int64) {
		let desc = task.taskDescription
		Task { @MainActor in Uploader.shared.progress(desc, sent: totalBytesSent) }
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		let desc = task.taskDescription
		let http = task.response as? HTTPURLResponse
		let status = http?.statusCode ?? 0
		let etag = http?.value(forHTTPHeaderField: "ETag")
		let cancelled = (error as? URLError)?.code == .cancelled
		if cancelled { return }
		Task { @MainActor in Uploader.shared.completed(desc, status: status, etag: etag, failed: error != nil) }
	}

	func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
		Task { @MainActor in
			// let the completion handlers above run first
			try? await Task.sleep(for: .milliseconds(300))
			Uploader.shared.eventsFinished()
		}
	}
}

private struct CreateUpload: Encodable {
	let name: String
	let size: Int64
	let type: String
	let takenAt: String?
	let takenAtSource: String?
	let lat: Double?
	let lng: Double?
	let locationSource: String?
	let caption: String
	let clientAssetId: String
}

private struct UploadStart: Decodable {
	let id: String
	let partSize: Int64?
	let partCount: Int?
	let duplicate: Bool?
	/// the post was already in the diary with its preview; the original starts over in place
	let preview: Bool?
}

private struct PartsBody: Encodable { let parts: [Int] }
private struct PartURLs: Decodable { let urls: [String: String] }
private struct CompleteBody: Encodable {
	struct Part: Encodable { let n: Int; let etag: String }
	let parts: [Part]
}
