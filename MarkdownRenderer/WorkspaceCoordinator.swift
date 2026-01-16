import AppKit
import Foundation

@MainActor
final class WorkspaceCoordinator: ObservableObject {
	@Published var folderURL: URL? {
		didSet { indexFolder() }
	}

	@Published private(set) var folderMarkdownFiles: [URL] = []
	@Published private(set) var isIndexing: Bool = false

	private var indexGeneration: Int = 0

	var recentMarkdownFiles: [URL] {
		NSDocumentController.shared.recentDocumentURLs
			.filter { $0.pathExtension.lowercased() == "md" }
	}

	func chooseFolder() {
		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.allowsMultipleSelection = false
		panel.prompt = "Open"
		panel.title = "Open Folder"

		guard panel.runModal() == .OK, let url = panel.url else { return }
		folderURL = url
	}

	func openFile(_ url: URL) {
		NSWorkspace.shared.open(url)
	}

	func displayName(for url: URL) -> String {
		guard let folderURL else { return url.lastPathComponent }
		let folderPath = folderURL.standardizedFileURL.path
		let filePath = url.standardizedFileURL.path
		guard filePath.hasPrefix(folderPath + "/") else { return url.lastPathComponent }
		return String(filePath.dropFirst(folderPath.count + 1))
	}

	private func indexFolder() {
		indexGeneration += 1
		let generation = indexGeneration

		guard let folderURL else {
			folderMarkdownFiles = []
			isIndexing = false
			return
		}

		isIndexing = true
		DispatchQueue.global(qos: .utility).async { [weak self, folderURL] in
			let fm = FileManager.default
			let keys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
			let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]

			var files: [URL] = []
			if let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: keys, options: options) {
				for case let url as URL in enumerator {
					if url.pathExtension.lowercased() != "md" { continue }
					files.append(url)
				}
			}

			files.sort { $0.path < $1.path }

			DispatchQueue.main.async {
				guard let self else { return }
				guard self.indexGeneration == generation else { return }
				self.folderMarkdownFiles = files
				self.isIndexing = false
			}
		}
	}
}
