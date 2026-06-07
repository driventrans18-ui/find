import Foundation
import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var username = ""
    @Published var results: [SearchResult] = []
    @Published var isSearching = false
    @Published var completedCount = 0

    let totalSites = SiteCatalog.all.count
    private let checker = UsernameChecker()
    private var task: Task<Void, Never>?

    var foundResults: [SearchResult] {
        results.filter(\.isFound).sorted { $0.site.name < $1.site.name }
    }

    var progress: Double {
        totalSites == 0 ? 0 : Double(completedCount) / Double(totalSites)
    }

    func search(history: HistoryStore) {
        let query = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        task?.cancel()
        results = []
        completedCount = 0
        isSearching = true

        task = Task {
            await checker.search(username: query, sites: SiteCatalog.all) { [weak self] result in
                guard let self else { return }
                self.results.append(result)
                self.completedCount += 1
            }
            if !Task.isCancelled {
                let found = self.results.filter(\.isFound).count
                history.add(SearchHistoryEntry(username: query,
                                               foundCount: found,
                                               totalCount: self.totalSites))
            }
            self.isSearching = false
        }
    }

    func cancel() {
        task?.cancel()
        isSearching = false
    }
}
