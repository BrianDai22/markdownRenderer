import SwiftUI

struct SidebarView: View {
	@EnvironmentObject private var workspace: WorkspaceCoordinator
	let outline: [OutlineItem]
	let onSelectOutline: (OutlineItem) -> Void

	@State private var fileFilter: String = ""

	var body: some View {
		List {
			if !outline.isEmpty {
				Section("Outline") {
					ForEach(outline) { item in
						Button {
							onSelectOutline(item)
						} label: {
							Text(item.title)
								.padding(.leading, CGFloat(max(0, item.level - 1)) * 10)
								.lineLimit(1)
								.truncationMode(.tail)
						}
					}
				}
			}

			Section("Recents") {
				let recents = workspace.recentMarkdownFiles
				if recents.isEmpty {
					Text("No recent files")
						.foregroundStyle(.secondary)
				} else {
					ForEach(recents, id: \.self) { url in
						Button {
							workspace.openFile(url)
						} label: {
							Text(url.lastPathComponent)
						}
					}
				}
			}

			Section("Workspace") {
				Button("Open Folder…") {
					workspace.chooseFolder()
				}
				.keyboardShortcut("O", modifiers: [.command, .shift])

				if let folderURL = workspace.folderURL {
					Text(folderURL.path)
						.font(.caption)
						.foregroundStyle(.secondary)
						.textSelection(.enabled)
				}
			}

			if let _ = workspace.folderURL {
				Section("Search") {
					TextField("Search…", text: $workspace.searchQuery)
						.textFieldStyle(.roundedBorder)

					if workspace.isSearching {
						HStack(spacing: 8) {
							ProgressView()
							Text("Searching…")
								.foregroundStyle(.secondary)
						}
					}

					if !workspace.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
						ForEach(workspace.searchResults, id: \.self) { url in
							Button {
								workspace.openFile(url)
							} label: {
								Text(workspace.displayName(for: url))
									.lineLimit(1)
									.truncationMode(.middle)
							}
						}
					}
				}

				Section("Files") {
					TextField("Filter…", text: $fileFilter)
						.textFieldStyle(.roundedBorder)

					if workspace.isIndexing {
						HStack(spacing: 8) {
							ProgressView()
							Text("Indexing…")
								.foregroundStyle(.secondary)
						}
					}

					let files = workspace.folderMarkdownFiles.filter { url in
						fileFilter.isEmpty || workspace.displayName(for: url).localizedCaseInsensitiveContains(fileFilter)
					}

					ForEach(files, id: \.self) { url in
						Button {
							workspace.openFile(url)
						} label: {
							Text(workspace.displayName(for: url))
								.lineLimit(1)
								.truncationMode(.middle)
						}
					}
				}
			}
		}
		.listStyle(.sidebar)
		.navigationTitle("Markdown")
	}
}
