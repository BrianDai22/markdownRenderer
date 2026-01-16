import SwiftUI
import UniformTypeIdentifiers

extension UTType {
	static let markdown = UTType(importedAs: "public.markdown")
}

struct MarkdownDocument: FileDocument {
	static var readableContentTypes: [UTType] { [.markdown] }

	var text: String

	init(text: String = "") {
		self.text = text
	}

	init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}

		if let string = String(data: data, encoding: .utf8) {
			self.text = string
			return
		}

		if let string = String(data: data, encoding: .utf16) {
			self.text = string
			return
		}

		throw CocoaError(.fileReadCorruptFile)
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let data = text.data(using: .utf8) ?? Data()
		return FileWrapper(regularFileWithContents: data)
	}
}
