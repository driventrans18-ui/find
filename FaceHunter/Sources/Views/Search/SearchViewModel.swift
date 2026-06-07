import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var selectedFilter: SearchEngine? = nil
    @Published var searchText: String = ""

    func filteredResults(from session: SearchSession) -> [SearchResult] {
        var results = session.deduplicatedResults
        if let engine = selectedFilter {
            results = results.filter { $0.sourceEngine == engine }
        }
        if !searchText.isEmpty {
            results = results.filter {
                $0.url.absoluteString.localizedCaseInsensitiveContains(searchText) ||
                $0.platform.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return results
    }
}
