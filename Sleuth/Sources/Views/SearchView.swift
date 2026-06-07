import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var history: HistoryStore
    @StateObject private var model = SearchViewModel()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if model.isSearching || !model.results.isEmpty {
                    progressHeader
                }

                content
            }
            .navigationTitle("Sleuth")
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "at")
                .foregroundStyle(.secondary)
            TextField("username", text: $model.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($fieldFocused)
                .submitLabel(.search)
                .onSubmit(runSearch)

            if model.isSearching {
                Button("Stop", role: .destructive) { model.cancel() }
            } else {
                Button("Search", action: runSearch)
                    .disabled(model.username.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .background(.bar)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: model.progress)
            Text("\(model.foundResults.count) found · \(model.completedCount)/\(model.totalSites) checked")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if model.results.isEmpty && !model.isSearching {
            ContentUnavailableView(
                "Search public profiles",
                systemImage: "person.text.rectangle",
                description: Text("Enter a username to see which sites have a public account with that handle.")
            )
        } else {
            List(model.foundResults) { result in
                ResultRow(result: result)
            }
            .listStyle(.plain)
            .overlay {
                if model.foundResults.isEmpty && !model.isSearching {
                    ContentUnavailableView(
                        "No accounts found",
                        systemImage: "magnifyingglass",
                        description: Text("No public profiles matched “\(model.username)”.")
                    )
                }
            }
        }
    }

    private func runSearch() {
        fieldFocused = false
        model.search(history: history)
    }
}
