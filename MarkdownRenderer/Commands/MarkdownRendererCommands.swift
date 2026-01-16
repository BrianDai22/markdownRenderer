import SwiftUI

struct MarkdownRendererCommands: Commands {
	@FocusedValue(\.layoutActions) private var layoutActions
	@FocusedValue(\.workspaceActions) private var workspaceActions

	var body: some Commands {
		CommandGroup(after: .sidebar) {
			Button("Open Folder…") { workspaceActions?.openFolder() }
				.keyboardShortcut("O", modifiers: [.command, .shift])

			Divider()

			Button("Toggle Preview") { layoutActions?.togglePreview() }
				.keyboardShortcut("p", modifiers: [.command, .shift])

			Button("Toggle Scroll Sync") { layoutActions?.toggleScrollSync() }
				.keyboardShortcut("y", modifiers: [.command, .shift])

			Divider()

			Button("Pin Layout to Tab") { layoutActions?.togglePin() }
				.keyboardShortcut("l", modifiers: [.command, .shift])

			Button("Apply Current Layout to All Tabs") { layoutActions?.applyLayoutToAllTabs() }
		}
	}
}
