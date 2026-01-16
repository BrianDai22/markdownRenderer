import SwiftUI

struct LayoutActions {
	let togglePreview: () -> Void
	let toggleScrollSync: () -> Void
	let togglePin: () -> Void
	let applyLayoutToAllTabs: () -> Void
}

struct WorkspaceActions {
	let openFolder: () -> Void
}

private struct LayoutActionsKey: FocusedValueKey {
	typealias Value = LayoutActions
}

private struct WorkspaceActionsKey: FocusedValueKey {
	typealias Value = WorkspaceActions
}

extension FocusedValues {
	var layoutActions: LayoutActions? {
		get { self[LayoutActionsKey.self] }
		set { self[LayoutActionsKey.self] = newValue }
	}

	var workspaceActions: WorkspaceActions? {
		get { self[WorkspaceActionsKey.self] }
		set { self[WorkspaceActionsKey.self] = newValue }
	}
}

struct DocumentSceneView: View {
	@EnvironmentObject private var layout: LayoutCoordinator
	@EnvironmentObject private var workspace: WorkspaceCoordinator

	@Binding var document: MarkdownDocument
	let fileURL: URL?

	@State private var isPinned: Bool = false
	@State private var pinned: LayoutSettings = .init()
	@StateObject private var previewController = PreviewController()

	@State private var lastLoadedText: String = ""
	@State private var lastDiskModDate: Date? = nil
	@State private var pendingDiskText: String? = nil
	@State private var showDiskReloadPrompt: Bool = false

	@State private var pendingDraftText: String? = nil
	@State private var showDraftRestorePrompt: Bool = false
	@State private var draftSaveTask: Task<Void, Never>? = nil
	@State private var draftStore: DraftStore = .live

	@State private var editorScrollProgress: Double = 0

	private var effective: LayoutSettings {
		isPinned ? pinned : layout.global
	}

	private func withMutableLayout(_ mutate: (inout LayoutSettings) -> Void) {
		if isPinned {
			mutate(&pinned)
		} else {
			var next = layout.global
			mutate(&next)
			layout.global = next
		}
	}

	private func setPinned(_ pinnedOn: Bool) {
		if pinnedOn, !isPinned {
			pinned = layout.global
		}
		isPinned = pinnedOn
	}

	private var isDirtyRelativeToDisk: Bool {
		document.text != lastLoadedText
	}

	private func pollDiskIfNeeded() {
		guard let fileURL else { return }
		guard fileURL.isFileURL else { return }

		let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
		if modDate == lastDiskModDate { return }

		Task.detached(priority: .utility) { [fileURL] in
			let diskText = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
			await MainActor.run {
					self.lastDiskModDate = modDate
					if diskText == self.document.text {
						self.lastLoadedText = diskText
						DraftStore.live.clear(for: fileURL)
						return
					}

				if self.isDirtyRelativeToDisk {
					self.pendingDiskText = diskText
					self.showDiskReloadPrompt = true
					} else {
						self.document.text = diskText
						self.lastLoadedText = diskText
						DraftStore.live.clear(for: fileURL)
					}
				}
			}
		}

	private func maybePromptDraftRestore() {
		guard let fileURL else { return }
		guard let draft = draftStore.load(for: fileURL) else { return }
		guard draft != document.text else { return }
		pendingDraftText = draft
		showDraftRestorePrompt = true
	}

	private func scheduleDraftSave() {
		guard let fileURL else { return }
		draftSaveTask?.cancel()
		let text = document.text
		draftSaveTask = Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(900))
			if Task.isCancelled { return }
			Task.detached(priority: .utility) { [fileURL, text] in
				DraftStore.live.save(text, for: fileURL)
			}
		}
	}

	var body: some View {
		NavigationSplitView {
			SidebarView()
		} detail: {
			HSplitView {
				EditorTextView(text: $document.text, onScroll: { editorScrollProgress = $0 })
					.frame(minWidth: 380)

				if effective.previewVisible {
					PreviewWebView(controller: previewController, markdown: document.text, baseURL: fileURL?.deletingLastPathComponent())
						.frame(minWidth: 420)
				}
			}
		}
		.toolbar {
			ToolbarItemGroup {
				Button {
					withMutableLayout { $0.previewVisible.toggle() }
				} label: {
					Image(systemName: effective.previewVisible ? "eye" : "eye.slash")
				}
				.help("Toggle Preview")

				Toggle(isOn: Binding(
					get: { effective.scrollSyncEnabled },
					set: { newValue in withMutableLayout { $0.scrollSyncEnabled = newValue } }
				)) {
					Image(systemName: "arrow.up.and.down.text.horizontal")
				}
				.toggleStyle(.button)
				.help("Scroll Sync (scaffold)")

				Toggle(isOn: Binding(
					get: { isPinned },
					set: { setPinned($0) }
				)) {
					Image(systemName: isPinned ? "pin.fill" : "pin")
				}
				.toggleStyle(.button)
				.help("Pin Layout to Tab")
			}
		}
		.onAppear {
			lastLoadedText = document.text
			lastDiskModDate = (try? fileURL?.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
			maybePromptDraftRestore()
		}
		.onChange(of: document.text) { _ in
			scheduleDraftSave()
		}
		.onChange(of: editorScrollProgress) { newValue in
			guard effective.scrollSyncEnabled else { return }
			previewController.scrollTo(progress: newValue)
		}
		.onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
			pollDiskIfNeeded()
		}
		.focusedValue(\.layoutActions, LayoutActions(
			togglePreview: { withMutableLayout { $0.previewVisible.toggle() } },
			toggleScrollSync: { withMutableLayout { $0.scrollSyncEnabled.toggle() } },
			togglePin: { setPinned(!isPinned) },
			applyLayoutToAllTabs: {
				let current = effective
				layout.global = current
				if isPinned {
					pinned = current
				}
			}
		))
		.focusedValue(\.workspaceActions, WorkspaceActions(
			openFolder: { workspace.chooseFolder() }
		))
		.alert("Restore Draft?", isPresented: $showDraftRestorePrompt) {
			Button("Restore") {
				if let draft = pendingDraftText {
					document.text = draft
				}
				pendingDraftText = nil
			}
			Button("Discard", role: .destructive) {
				if let fileURL {
					draftStore.clear(for: fileURL)
				}
				pendingDraftText = nil
			}
		} message: {
			Text("A newer draft was found for this file.")
		}
		.alert("File Changed on Disk", isPresented: $showDiskReloadPrompt) {
			Button("Reload") {
				if let disk = pendingDiskText {
					document.text = disk
					lastLoadedText = disk
				}
				pendingDiskText = nil
			}
			Button("Keep Mine", role: .cancel) {
				pendingDiskText = nil
			}
		} message: {
			Text("This file was modified outside the app.")
		}
	}
}
