import Foundation

enum MarkdownHTMLRenderer {
	static func render(markdown: String) -> String {
		let escaped = escapeHTML(markdown)
		let withCode = renderCodeFences(escaped)
		let withHeadings = renderHeadings(withCode)
		let withInline = renderInline(withHeadings)
		let withBlocks = renderBlocks(withInline)
		return withBlocks
	}

	private static func escapeHTML(_ input: String) -> String {
		input
			.replacingOccurrences(of: "&", with: "&amp;")
			.replacingOccurrences(of: "<", with: "&lt;")
			.replacingOccurrences(of: ">", with: "&gt;")
	}

	private static func renderCodeFences(_ input: String) -> String {
		let lines = input.split(separator: "\n", omittingEmptySubsequences: false)
		var out: [String] = []
		var inFence = false
		var fenceLang: String? = nil
		var buffer: [Substring] = []

		func flushFence() {
			let code = buffer.joined(separator: "\n")
			let langClass = fenceLang.map { " class=\"language-\($0)\"" } ?? ""
			out.append("<pre><code\(langClass)>\(code)</code></pre>")
			buffer.removeAll(keepingCapacity: true)
			fenceLang = nil
		}

		for line in lines {
			if line.hasPrefix("```") {
				if inFence {
					flushFence()
					inFence = false
				} else {
					inFence = true
					let lang = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
					fenceLang = lang.isEmpty ? nil : String(lang)
				}
				continue
			}

			if inFence {
				buffer.append(line)
			} else {
				out.append(String(line))
			}
		}

		if inFence {
			flushFence()
		}

		return out.joined(separator: "\n")
	}

	private static func renderHeadings(_ input: String) -> String {
		let lines = input.split(separator: "\n", omittingEmptySubsequences: false)
		return lines.map { line in
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			guard trimmed.hasPrefix("#") else { return String(line) }
			let hashes = trimmed.prefix { $0 == "#" }.count
			guard (1...6).contains(hashes) else { return String(line) }
			let title = trimmed.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
			let id = slug(String(title))
			return "<h\(hashes) id=\"\(id)\">\(title)</h\(hashes)>"
		}.joined(separator: "\n")
	}

	private static func renderInline(_ input: String) -> String {
		var s = input
		s = replaceRegex(s, pattern: "`([^`]+)`", template: "<code>$1</code>")
		s = replaceRegex(s, pattern: "\\*\\*([^*]+)\\*\\*", template: "<strong>$1</strong>")
		s = replaceRegex(s, pattern: "_([^_]+)_", template: "<em>$1</em>")
		s = replaceRegex(s, pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", template: "<a href=\"$2\">$1</a>")
		s = replaceRegex(s, pattern: "!\\[([^\\]]*)\\]\\(([^\\)]+)\\)", template: "<img alt=\"$1\" src=\"$2\" />")
		return s
	}

	private static func renderBlocks(_ input: String) -> String {
		let parts = input
			.replacingOccurrences(of: "\r\n", with: "\n")
			.components(separatedBy: "\n\n")

		var out: [String] = []
		var inList = false
		var listItems: [String] = []

		func flushList() {
			guard inList else { return }
			out.append("<ul>\n" + listItems.joined(separator: "\n") + "\n</ul>")
			listItems.removeAll(keepingCapacity: true)
			inList = false
		}

		for part in parts {
			let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
			if trimmed.isEmpty { continue }

			if trimmed.hasPrefix("<h") || trimmed.hasPrefix("<pre>") {
				flushList()
				out.append(trimmed)
				continue
			}

			let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
			let isBulleted = lines.allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- ") }
			if isBulleted {
				inList = true
				for line in lines {
					let item = line.trimmingCharacters(in: .whitespaces).dropFirst(2)
					listItems.append("<li>\(item)</li>")
				}
				continue
			}

			flushList()
			out.append("<p>\(trimmed.replacingOccurrences(of: "\n", with: "<br/>"))</p>")
		}

		flushList()
		return out.joined(separator: "\n")
	}

	private static func replaceRegex(_ input: String, pattern: String, template: String) -> String {
		guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return input }
		let range = NSRange(input.startIndex..<input.endIndex, in: input)
		return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: template)
	}

	private static func slug(_ input: String) -> String {
		let lowered = input.lowercased()
		let allowed = lowered.map { ch -> Character in
			if ch.isLetter || ch.isNumber { return ch }
			return "-"
		}
		let collapsed = String(allowed).replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
		return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
	}
}

