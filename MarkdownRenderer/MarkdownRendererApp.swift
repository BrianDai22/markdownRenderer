import SwiftUI

@main
struct MarkdownRendererApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var layout = LayoutCoordinator()
	@StateObject private var workspace = WorkspaceCoordinator()

	var body: some Scene {
		DocumentGroup(newDocument: MarkdownDocument()) { file in
			DocumentSceneView(document: file.$document, fileURL: file.fileURL)
				.environmentObject(layout)
				.environmentObject(workspace)
		}
		.commands {
			MarkdownRendererCommands()
		}
	}
}
