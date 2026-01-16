import AppKit
import SwiftUI

struct EditorTextView: NSViewRepresentable {
	let controller: EditorController
	@Binding var text: String
	var onScroll: ((Double) -> Void)? = nil

	func makeNSView(context: Context) -> NSScrollView {
		let textView = MarkdownTextView()
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
		controller.textView = textView

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

	@MainActor
	final class Coordinator: NSObject, NSTextViewDelegate {
		@Binding var text: String
		private let onScroll: ((Double) -> Void)?
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
			NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(boundsDidChange(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
		}

		@objc private func boundsDidChange(_ notification: Notification) {
			handleScroll()
		}

		private func handleScroll() {
			guard let onScroll, let scrollView, let documentView = scrollView.documentView else { return }
			let clipHeight = scrollView.contentView.bounds.height
			let maxY = max(1, documentView.frame.height - clipHeight)
			let y = scrollView.contentView.bounds.origin.y
			onScroll(min(max(Double(y / maxY), 0), 1))
		}

		deinit {
			NotificationCenter.default.removeObserver(self)
		}
	}
}

@MainActor
final class EditorController: ObservableObject {
	weak var textView: NSTextView?

	func scrollTo(line: Int) {
		guard line >= 0 else { return }
		guard let textView else { return }

		let ns = textView.string as NSString
		var currentLine = 0
		var location = 0

		while location < ns.length, currentLine < line {
			let range = ns.lineRange(for: NSRange(location: location, length: 0))
			location = NSMaxRange(range)
			currentLine += 1
		}

		let target = ns.lineRange(for: NSRange(location: min(location, ns.length), length: 0))
		textView.setSelectedRange(NSRange(location: target.location, length: 0))
		textView.scrollRangeToVisible(target)
		textView.window?.makeFirstResponder(textView)
	}
}

private final class MarkdownTextView: NSTextView {
	override func keyDown(with event: NSEvent) {
		guard let characters = event.charactersIgnoringModifiers, characters.count == 1 else {
			super.keyDown(with: event)
			return
		}

		switch characters {
		case "\t":
			handleIndent(outdent: event.modifierFlags.contains(.shift))
		case "\n", "\r":
			if handleListContinuation() { return }
			super.keyDown(with: event)
		case "(", "[", "{", "\"", "'", "`":
			if handleAutoPair(open: characters) { return }
			super.keyDown(with: event)
		case ")", "]", "}":
			if handleSkipOverClosing(close: characters) { return }
			super.keyDown(with: event)
		default:
			super.keyDown(with: event)
		}
	}

	private func handleIndent(outdent: Bool) {
		let selection = selectedRange()
		guard let storage = textStorage else { return }

		let ns = (string as NSString)
		let lineRange = ns.lineRange(for: selection)
		let full = ns.substring(with: lineRange)
		let lines = full.split(separator: "\n", omittingEmptySubsequences: false)

		let indent = "  "
		var outLines: [String] = []
		outLines.reserveCapacity(lines.count)

		for line in lines {
			let s = String(line)
			if outdent {
				if s.hasPrefix(indent) {
					outLines.append(String(s.dropFirst(indent.count)))
				} else if s.hasPrefix("\t") {
					outLines.append(String(s.dropFirst(1)))
				} else {
					outLines.append(s)
				}
			} else {
				outLines.append(indent + s)
			}
		}

		let replacement = outLines.joined(separator: "\n")
		shouldChangeText(in: lineRange, replacementString: replacement)
		storage.replaceCharacters(in: lineRange, with: replacement)
		didChangeText()

		let delta = replacement.count - full.count
		setSelectedRange(NSRange(location: selection.location + (outdent ? 0 : indent.count), length: max(0, selection.length + delta)))
	}

	private func handleListContinuation() -> Bool {
		let selection = selectedRange()
		guard selection.length == 0 else { return false }

		let ns = string as NSString
		let lineRange = ns.lineRange(for: NSRange(location: selection.location, length: 0))
		let line = ns.substring(with: lineRange)
		let lineSansNewline = line.trimmingCharacters(in: CharacterSet.newlines)

		let caretInLine = selection.location - lineRange.location
		if caretInLine < lineSansNewline.count { return false }

		let trimmed = lineSansNewline
		let prefix = listPrefix(for: trimmed)
		guard let prefix else { return false }

		let content = trimmed.dropFirst(prefix.count)
		if content.trimmingCharacters(in: .whitespaces).isEmpty {
			// end list: replace line with just indentation + newline
			let indentation = prefix.leadingWhitespace()
			insertText("\n" + indentation, replacementRange: selection)
			return true
		}

		insertText("\n" + prefix, replacementRange: selection)
		return true
	}

	private func listPrefix(for line: String) -> String? {
		let trimmed = line
		let wsCount = trimmed.prefix { $0 == " " || $0 == "\t" }.count
		let leading = String(trimmed.prefix(wsCount))
		let rest = trimmed.dropFirst(wsCount)

		if rest.hasPrefix("- [ ] ") || rest.hasPrefix("- [x] ") || rest.hasPrefix("- [X] ") {
			return leading + "- [ ] "
		}

		if rest.hasPrefix("- ") || rest.hasPrefix("* ") || rest.hasPrefix("+ ") {
			return leading + String(rest.prefix(2))
		}

		if let match = rest.range(of: #"^(\d+)\.\s"#, options: .regularExpression) {
			let token = String(rest[match])
			let numberPart = token.split(separator: ".").first.flatMap { Int($0) } ?? 0
			return leading + "\(numberPart + 1). "
		}

		return nil
	}

	private func handleAutoPair(open: String) -> Bool {
		let pairs: [String: String] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'", "`": "`"]
		guard let close = pairs[open] else { return false }

		let selection = selectedRange()
		if selection.length == 0, open == close, handleSkipOverClosing(close: close) {
			return true
		}

		if selection.length > 0 {
			let ns = string as NSString
			let selectedText = ns.substring(with: selection)
			insertText(open + selectedText + close, replacementRange: selection)
			return true
		}

		insertText(open + close, replacementRange: selection)
		setSelectedRange(NSRange(location: selection.location + open.count, length: 0))
		return true
	}

	private func handleSkipOverClosing(close: String) -> Bool {
		let selection = selectedRange()
		guard selection.length == 0 else { return false }

		let ns = string as NSString
		guard selection.location < ns.length else { return false }
		let next = ns.substring(with: NSRange(location: selection.location, length: 1))
		guard next == close else { return false }
		setSelectedRange(NSRange(location: selection.location + 1, length: 0))
		return true
	}
}

private extension String {
	func leadingWhitespace() -> String {
		String(prefix { $0 == " " || $0 == "\t" })
	}
}
