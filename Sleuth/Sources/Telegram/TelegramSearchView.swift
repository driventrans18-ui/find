import SwiftUI
import WebKit

// MARK: - ViewModel

@MainActor
final class TelegramSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var submittedQuery = ""

    func search() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        submittedQuery = q
    }
}

// MARK: - View

struct TelegramSearchView: View {
    @StateObject private var vm = TelegramSearchViewModel()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider()
                if vm.submittedQuery.isEmpty {
                    emptyState
                } else {
                    TelegramBrowserView(query: vm.submittedQuery)
                }
            }
            .navigationTitle("Telegram")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search channels, groups, topics…", text: $vm.query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .submitLabel(.search)
                .onSubmit(vm.search)
            if !vm.query.isEmpty {
                Button("Search", action: vm.search)
            }
        }
        .padding()
        .background(.bar)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Search Telegram",
            systemImage: "paperplane.fill",
            description: Text("Type a keyword to search public channels, groups, and bots via TGStat.")
        )
    }
}

// MARK: - Embedded browser that loads TGStat search

struct TelegramBrowserView: UIViewRepresentable {
    let query: String

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .automatic
        load(query: query, into: wv)
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        // Reload when query changes
        if context.coordinator.lastQuery != query {
            context.coordinator.lastQuery = query
            load(query: query, into: wv)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func load(query: String, into wv: WKWebView) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlStr = "https://tgstat.com/en/search?q=\(encoded)"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        wv.load(req)
    }

    final class Coordinator {
        var lastQuery: String = ""
    }
}
