import AVFoundation
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// A picked photo/video the app can't open in the library (Photos access is limited to other photos, or denied):
/// a copy of the file the picker handed over, kept until it's sent. Where and when it was taken come from the file.
struct PickedFile: Codable, Hashable, Sendable {
	/// "file:<uuid>", used where library items use their asset id
	let id: String
	/// file name inside `PickedFiles.folder`
	let path: String
	let name: String
	let mime: String
	let isVideo: Bool
	let takenAt: Date?
	let lat: Double?
	let lng: Double?

	var url: URL { PickedFiles.folder.appending(path: path) }
	var hasLocation: Bool { lat != nil && lng != nil }
}

enum PickedFiles {
	static let folder: URL = {
		let url = URL.applicationSupportDirectory.appending(path: "picked", directoryHint: .isDirectory)
		try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		return url
	}()

	/// The picker's copy of the file (any type it offers), moved into our folder.
	private struct Received: Transferable {
		let url: URL
		static var transferRepresentation: some TransferRepresentation {
			FileRepresentation(importedContentType: .movie) { try Received(url: keep($0.file)) }
			FileRepresentation(importedContentType: .image) { try Received(url: keep($0.file)) }
		}
		private static func keep(_ file: URL) throws -> URL {
			let dest = PickedFiles.folder.appending(path: "\(UUID().uuidString).\(file.pathExtension.isEmpty ? "bin" : file.pathExtension)")
			try FileManager.default.copyItem(at: file, to: dest)
			return dest
		}
	}

	/// Copies a picked item and reads its date and location. nil when the picker couldn't hand it over.
	static func load(_ item: PhotosPickerItem) async -> PickedFile? {
		guard let r = try? await item.loadTransferable(type: Received.self) else { return nil }
		let type = UTType(filenameExtension: r.url.pathExtension)
		let isVideo = type?.conforms(to: .movie) ?? item.supportedContentTypes.contains { $0.conforms(to: .movie) }
		let mime = type?.preferredMIMEType ?? (isVideo ? "video/quicktime" : "image/jpeg")
		let meta = isVideo ? await videoMeta(r.url) : imageMeta(r.url)
		let uuid = r.url.deletingPathExtension().lastPathComponent
		return PickedFile(id: "file:\(uuid)", path: r.url.lastPathComponent, name: "\(isVideo ? "video" : "foto")-\(uuid.prefix(8)).\(r.url.pathExtension)",
						  mime: mime, isVideo: isVideo, takenAt: meta.date, lat: meta.lat, lng: meta.lng)
	}

	static func remove(_ f: PickedFile) { try? FileManager.default.removeItem(at: f.url) }

	/// EXIF date (with its time zone when the photo says) and GPS.
	private static func imageMeta(_ url: URL) -> (date: Date?, lat: Double?, lng: Double?) {
		guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
			  let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return (nil, nil, nil) }
		var date: Date?
		if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any], let s = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
			let f = DateFormatter()
			f.locale = Locale(identifier: "en_US_POSIX")
			if let off = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String {
				f.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
				date = f.date(from: s + off)
			}
			if date == nil {
				f.dateFormat = "yyyy:MM:dd HH:mm:ss"
				f.timeZone = .current
				date = f.date(from: s)
			}
		}
		var lat: Double?, lng: Double?
		if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
		   let a = gps[kCGImagePropertyGPSLatitude] as? Double, let b = gps[kCGImagePropertyGPSLongitude] as? Double, !(a == 0 && b == 0) {
			lat = (gps[kCGImagePropertyGPSLatitudeRef] as? String) == "S" ? -a : a
			lng = (gps[kCGImagePropertyGPSLongitudeRef] as? String) == "W" ? -b : b
		}
		return (date, lat, lng)
	}

	/// The video's creation date and its ISO 6709 location ("+12.3456-045.6789+000.000/").
	private static func videoMeta(_ url: URL) async -> (date: Date?, lat: Double?, lng: Double?) {
		let asset = AVURLAsset(url: url)
		let date = try? await asset.load(.creationDate)?.load(.dateValue)
		var lat: Double?, lng: Double?
		if let items = try? await asset.load(.commonMetadata),
		   let loc = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierLocation).first,
		   let s = try? await loc.load(.stringValue),
		   let m = s.firstMatch(of: /([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)/) {
			lat = Double(m.1)
			lng = Double(m.2)
		}
		return (date, lat, lng)
	}

	/// A small picture of the file (the video's first frame).
	static func thumbnail(_ f: PickedFile, side: CGFloat = 240) async -> UIImage? {
		if f.isVideo {
			let gen = AVAssetImageGenerator(asset: AVURLAsset(url: f.url))
			gen.appliesPreferredTrackTransform = true
			gen.maximumSize = CGSize(width: side, height: side)
			guard let cg = try? await gen.image(at: .zero).image else { return nil }
			return UIImage(cgImage: cg)
		}
		guard let src = CGImageSourceCreateWithURL(f.url as CFURL, nil) else { return nil }
		let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
									 kCGImageSourceThumbnailMaxPixelSize: side]
		guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
		return UIImage(cgImage: cg)
	}
}
