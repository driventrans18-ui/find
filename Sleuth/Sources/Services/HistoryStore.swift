import Foundation

/// Persists completed searches to `UserDefaults` so history survives launches.
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [SearchHistoryEntry] = []

    private let key = "search_history"
    private let limit = 100

    init() { load() }

    func add(_ entry: SearchHistoryEntry) {
        entries.insert(entry, at: 0)
        if entries.count > limit { entries.removeLast(entries.count - limit) }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SearchHistoryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
