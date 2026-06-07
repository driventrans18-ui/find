import Foundation

/// Loads the bundled site list from `sites.json`.
enum SiteCatalog {
    static let all: [SiteTarget] = load()

    static var categories: [String] {
        Array(Set(all.map(\.category))).sorted()
    }

    private static func load() -> [SiteTarget] {
        guard let url = Bundle.main.url(forResource: "sites", withExtension: "json") else {
            assertionFailure("sites.json missing from bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([SiteTarget].self, from: data)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            assertionFailure("Failed to decode sites.json: \(error)")
            return []
        }
    }
}
