import Foundation

struct LayoutSettings: Codable, Equatable {
	var previewVisible: Bool = true
	var scrollSyncEnabled: Bool = true
}

@MainActor
final class LayoutCoordinator: ObservableObject {
	@Published var global: LayoutSettings {
		didSet { saveGlobal() }
	}

	private static let globalDefaultsKey = "layout.global.v1"

	init() {
		self.global = Self.loadGlobal()
	}

	private func saveGlobal() {
		do {
			let data = try JSONEncoder().encode(global)
			UserDefaults.standard.set(data, forKey: Self.globalDefaultsKey)
		} catch {
			UserDefaults.standard.removeObject(forKey: Self.globalDefaultsKey)
		}
	}

	private static func loadGlobal() -> LayoutSettings {
		guard let data = UserDefaults.standard.data(forKey: globalDefaultsKey) else {
			return LayoutSettings()
		}
		return (try? JSONDecoder().decode(LayoutSettings.self, from: data)) ?? LayoutSettings()
	}
}

