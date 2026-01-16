import Foundation
import Testing
@testable import MarkdownRendererLib

@Suite("WorkspaceCoordinator")
struct WorkspaceCoordinatorTests {
	@Test("Display name uses relative path when inside folder")
	@MainActor
	func displayNameRelative() {
		let workspace = WorkspaceCoordinator()
		let folder = URL(fileURLWithPath: "/tmp/workspace", isDirectory: true)
		workspace.folderURL = folder

		let file = folder.appendingPathComponent("docs/readme.md")
		#expect(workspace.displayName(for: file) == "docs/readme.md")
	}

	@Test("Display name falls back when outside folder")
	@MainActor
	func displayNameFallback() {
		let workspace = WorkspaceCoordinator()
		workspace.folderURL = URL(fileURLWithPath: "/tmp/workspace", isDirectory: true)

		let file = URL(fileURLWithPath: "/tmp/other/note.md")
		#expect(workspace.displayName(for: file) == "note.md")
	}
}

