import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        NavigationStack {
            Group {
                if history.entries.isEmpty {
                    ContentUnavailableView(
                        "No searches yet",
                        systemImage: "clock",
                        description: Text("Your past searches will appear here.")
                    )
                } else {
                    List(history.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("@\(entry.username)")
                                .font(.headline)
                            Text("\(entry.foundCount) of \(entry.totalCount) sites · \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !history.entries.isEmpty {
                    Button("Clear", role: .destructive) { history.clear() }
                }
            }
        }
    }
}
