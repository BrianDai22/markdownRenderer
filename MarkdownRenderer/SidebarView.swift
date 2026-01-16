import SwiftUI

struct SidebarView: View {
	@EnvironmentObject private var workspace: WorkspaceCoordinator

	var body: some View {
		List {
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
				Section("Files") {
					if workspace.isIndexing {
						HStack(spacing: 8) {
							ProgressView()
							Text("Indexing…")
								.foregroundStyle(.secondary)
						}
					}

					ForEach(workspace.folderMarkdownFiles, id: \.self) { url in
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

