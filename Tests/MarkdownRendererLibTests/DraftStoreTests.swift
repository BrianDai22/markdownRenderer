import Foundation
import Testing
@testable import MarkdownRendererLib

@Suite("DraftStore")
struct DraftStoreTests {
	@Test("Save/load/clear roundtrip")
	func roundtrip() throws {
		let root = FileManager.default.temporaryDirectory
			.appendingPathComponent("MarkdownRendererTests", isDirectory: true)
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let store = DraftStore(rootURL: root)

		let fileURL = root.appendingPathComponent("note.md")
		#expect(store.load(for: fileURL) == nil)

		store.save("hello", for: fileURL)
		#expect(store.load(for: fileURL) == "hello")

		store.clear(for: fileURL)
		#expect(store.load(for: fileURL) == nil)
	}
}

