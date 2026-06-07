import SwiftUI

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var session: SearchSession
    @Published var showingShareSheet = false
    @Published var shareItems: [Any] = []

    private let searchVM = SearchViewModel()

    var search: SearchViewModel { searchVM }

    init(session: SearchSession) {
        self.session = session
    }

    func update(session: SearchSession) {
        self.session = session
    }

    var displayedResults: [SearchResult] {
        searchVM.filteredResults(from: session)
    }

    func prepareExport() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(session.deduplicatedResults),
              let json = String(data: data, encoding: .utf8) else { return }
        shareItems = [json]
        showingShareSheet = true
    }
}
