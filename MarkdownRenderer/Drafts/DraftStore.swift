import CryptoKit
import Foundation

struct DraftStore: Sendable {
	let rootURL: URL

	static var live: DraftStore {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let root = appSupport
			.appendingPathComponent("MarkdownRenderer", isDirectory: true)
			.appendingPathComponent("Drafts", isDirectory: true)
		return DraftStore(rootURL: root)
	}

	func load(for fileURL: URL) -> String? {
		guard let url = draftURL(for: fileURL) else { return nil }
		return try? String(contentsOf: url, encoding: .utf8)
	}

	func save(_ text: String, for fileURL: URL) {
		guard let url = draftURL(for: fileURL) else { return }
		do {
			try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
			try text.data(using: .utf8)?.write(to: url, options: [.atomic])
		} catch {
			// best-effort
		}
	}

	func clear(for fileURL: URL) {
		guard let url = draftURL(for: fileURL) else { return }
		try? FileManager.default.removeItem(at: url)
	}

	private func draftURL(for fileURL: URL) -> URL? {
		guard fileURL.isFileURL else { return nil }
		let key = fileURL.standardizedFileURL.path
		let digest = SHA256.hash(data: Data(key.utf8))
		let name = digest.compactMap { String(format: "%02x", $0) }.joined()
		return rootURL.appendingPathComponent(name).appendingPathExtension("txt")
	}
}

