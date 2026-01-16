import Foundation

struct OutlineItem: Identifiable, Equatable {
	let id: String
	let level: Int
	let title: String
	let line: Int
}

enum OutlineParser {
	static func parse(markdown: String) -> [OutlineItem] {
		let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
		var inFence = false
		var usedIDs: [String: Int] = [:]

		var items: [OutlineItem] = []
		items.reserveCapacity(64)

		for (lineIndex, rawLine) in lines.enumerated() {
			let line = String(rawLine)
			let trimmed = line.trimmingCharacters(in: .whitespaces)

			if trimmed.hasPrefix("```") {
				inFence.toggle()
				continue
			}
			if inFence { continue }

			let hashes = trimmed.prefix { $0 == "#" }.count
			guard (1...6).contains(hashes) else { continue }
			guard trimmed.dropFirst(hashes).first == " " else { continue }

			let title = String(trimmed.dropFirst(hashes)).trimmingCharacters(in: .whitespaces)
			guard !title.isEmpty else { continue }

			let base = slugify(title)
			let unique = uniquedSlug(base, used: &usedIDs)
			items.append(OutlineItem(id: unique, level: hashes, title: title, line: lineIndex))
		}

		return items
	}

	private static func uniquedSlug(_ slug: String, used: inout [String: Int]) -> String {
		if used[slug] == nil {
			used[slug] = 0
			return slug
		}

		var suffix = (used[slug] ?? 0) + 1
		while used["\(slug)-\(suffix)"] != nil {
			suffix += 1
		}

		used[slug] = suffix
		used["\(slug)-\(suffix)"] = 0
		return "\(slug)-\(suffix)"
	}

	private static func slugify(_ title: String) -> String {
		let lowered = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		let dashed = lowered.replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
		let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
		return dashed.addingPercentEncoding(withAllowedCharacters: unreserved) ?? dashed
	}
}
