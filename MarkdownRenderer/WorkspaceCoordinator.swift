import AppKit
import Foundation

@MainActor
final class WorkspaceCoordinator: ObservableObject {
	@Published var folderURL: URL? {
		didSet { configureFolder() }
	}

	@Published var searchQuery: String = "" {
		didSet { scheduleSearch() }
	}

	@Published private(set) var folderMarkdownFiles: [URL] = []
	@Published private(set) var isIndexing: Bool = false
	@Published private(set) var isSearching: Bool = false
	@Published private(set) var searchResults: [URL] = []

	private var indexGeneration: Int = 0
	private var folderWatcher: FileSystemWatcher?
	private var reindexTask: Task<Void, Never>?
	private var searchTask: Task<Void, Never>?

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

	private func configureFolder() {
		reindexTask?.cancel()
		folderWatcher?.stop()
		folderWatcher = nil

		guard let folderURL else {
			folderMarkdownFiles = []
			isIndexing = false
			return
		}

		folderWatcher = FileSystemWatcher(url: folderURL) { [weak self] in
			guard let self else { return }
			self.scheduleReindex()
		}
		folderWatcher?.start()
		indexFolder()
	}

	private func scheduleReindex() {
		reindexTask?.cancel()
		reindexTask = Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(250))
			if Task.isCancelled { return }
			indexFolder()
		}
	}

	private func scheduleSearch() {
		searchTask?.cancel()
		let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
		if query.isEmpty {
			isSearching = false
			searchResults = []
			return
		}

		isSearching = true
		searchTask = Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(150))
			if Task.isCancelled { return }
			await self.performSearch(query: query)
		}
	}

	private func performSearch(query: String) async {
		guard let folderURL else {
			isSearching = false
			searchResults = []
			return
		}

		let candidates = folderMarkdownFiles
		let lower = query.lowercased()

		let results: [URL] = await Task.detached(priority: .utility) {
			var matches: [URL] = []
			matches.reserveCapacity(64)

			for url in candidates {
				if Task.isCancelled { return matches }
				let name = url.lastPathComponent.lowercased()
				if name.contains(lower) {
					matches.append(url)
					continue
				}

				// Best-effort content search: cap read size.
				guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
				defer { try? handle.close() }
				let data = (try? handle.read(upToCount: 300_000)) ?? nil
				guard let data, let text = String(data: data, encoding: .utf8) else { continue }
				if text.lowercased().contains(lower) {
					matches.append(url)
				}

				if matches.count >= 200 { break }
			}

			return matches
		}.value

		guard folderURL == self.folderURL else { return }
		searchResults = results
		isSearching = false
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
