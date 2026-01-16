import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ notification: Notification) {
		NSWindow.allowsAutomaticWindowTabbing = true
	}

	func applicationDidBecomeActive(_ notification: Notification) {
		for window in NSApplication.shared.windows {
			window.tabbingMode = .preferred
		}
	}
}
