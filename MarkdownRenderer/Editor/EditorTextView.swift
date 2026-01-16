import AppKit
import SwiftUI

struct EditorTextView: NSViewRepresentable {
	@Binding var text: String
	var onScroll: ((Double) -> Void)? = nil

	func makeNSView(context: Context) -> NSScrollView {
		let textView = NSTextView()
		textView.isRichText = false
		textView.isAutomaticQuoteSubstitutionEnabled = false
		textView.isAutomaticDashSubstitutionEnabled = false
		textView.isAutomaticTextReplacementEnabled = false
		textView.isAutomaticSpellingCorrectionEnabled = true
		textView.allowsUndo = true
		textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
		textView.textColor = NSColor.labelColor
		textView.backgroundColor = NSColor.textBackgroundColor
		textView.delegate = context.coordinator
		textView.string = text

		let scrollView = NSScrollView()
		scrollView.hasVerticalScroller = true
		scrollView.drawsBackground = true
		scrollView.documentView = textView

		scrollView.contentView.postsBoundsChangedNotifications = true
		context.coordinator.attachScrollObserver(scrollView: scrollView)

		return scrollView
	}

	func updateNSView(_ nsView: NSScrollView, context: Context) {
		guard let textView = nsView.documentView as? NSTextView else { return }
		if textView.string != text {
			textView.string = text
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(text: $text, onScroll: onScroll)
	}

	final class Coordinator: NSObject, NSTextViewDelegate {
		@Binding var text: String
		private let onScroll: ((Double) -> Void)?
		private var boundsObserver: NSObjectProtocol?
		private weak var scrollView: NSScrollView?

		init(text: Binding<String>, onScroll: ((Double) -> Void)?) {
			self._text = text
			self.onScroll = onScroll
		}

		func textDidChange(_ notification: Notification) {
			guard let textView = notification.object as? NSTextView else { return }
			text = textView.string
		}

		func attachScrollObserver(scrollView: NSScrollView) {
			self.scrollView = scrollView
			boundsObserver.map { NotificationCenter.default.removeObserver($0) }
			boundsObserver = NotificationCenter.default.addObserver(
				forName: NSView.boundsDidChangeNotification,
				object: scrollView.contentView,
				queue: .main
			) { [weak self] _ in
				self?.handleScroll()
			}
		}

		private func handleScroll() {
			guard let onScroll, let scrollView, let documentView = scrollView.documentView else { return }
			let clipHeight = scrollView.contentView.bounds.height
			let maxY = max(1, documentView.frame.height - clipHeight)
			let y = scrollView.contentView.bounds.origin.y
			onScroll(min(max(Double(y / maxY), 0), 1))
		}

		deinit {
			boundsObserver.map { NotificationCenter.default.removeObserver($0) }
		}
	}
}
