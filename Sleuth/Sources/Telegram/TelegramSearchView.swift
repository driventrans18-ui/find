import SwiftUI

// MARK: - ViewModel

@MainActor
final class TelegramSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [TelegramSearchResult] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private let service = TelegramSearchService()
    private var task: Task<Void, Never>?

    func search() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        task?.cancel()
        results = []
        isSearching = true
        errorMessage = nil

        task = Task {
            do {
                let r = try await service.search(query: q)
                if !Task.isCancelled {
                    results = r
                    if r.isEmpty { errorMessage = "No channels or groups found for "\(q)"." }
                }
            } catch {
                if !Task.isCancelled { errorMessage = "Search failed: \(error.localizedDescription)" }
            }
            isSearching = false
        }
    }

    func cancel() { task?.cancel(); isSearching = false }
}

// MARK: - View

struct TelegramSearchView: View {
    @StateObject private var vm = TelegramSearchViewModel()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                content
            }
            .navigationTitle("Telegram")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search channels, groups, topics…", text: $vm.query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .submitLabel(.search)
                .onSubmit(vm.search)

            if vm.isSearching {
                Button("Stop", role: .destructive) { vm.cancel() }
            } else if !vm.query.isEmpty {
                Button("Search", action: vm.search)
            }
        }
        .padding()
        .background(.bar)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if vm.isSearching {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                Text("Searching TGStat…")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
        } else if let err = vm.errorMessage {
            ContentUnavailableView(
                "No results",
                systemImage: "magnifyingglass",
                description: Text(err)
            )
        } else if vm.results.isEmpty && !vm.query.isEmpty {
            emptyState
        } else if vm.results.isEmpty {
            emptyState
        } else {
            List(vm.results) { result in
                TelegramResultRow(result: result)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .listStyle(.plain)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Search Telegram",
            systemImage: "paperplane.fill",
            description: Text("Type a keyword to search channels, groups, and bots across Telegram's public database via TGStat.")
        )
    }
}

// MARK: - Result Row

struct TelegramResultRow: View {
    let result: TelegramSearchResult
    @State private var browserURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(result.title)
                        .font(.headline)
                        .lineLimit(1)
                    typeBadge
                }
                if let user = result.username {
                    Text("@\(user)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !result.description.isEmpty {
                    Text(result.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if !result.subscriberCount.isEmpty {
                    Label(result.subscriberCount + " subscribers", systemImage: "person.2")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            actionButtons
        }
        .padding(.vertical, 4)
        .sheet(item: $browserURL) { url in InAppBrowser(url: url) }
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = result.avatarURL {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                placeholderAvatar
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: 48, height: 48)
            .overlay {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.accentColor)
            }
    }

    private var typeBadge: some View {
        Text(result.type.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch result.type {
        case .channel: return .blue
        case .group:   return .green
        case .bot:     return .purple
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 6) {
            // Open in Telegram app
            if let tgURL = result.telegramURL {
                Button {
                    UIApplication.shared.open(tgURL)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            // Open TGStat page in browser
            Button {
                browserURL = result.tgstatURL
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}
