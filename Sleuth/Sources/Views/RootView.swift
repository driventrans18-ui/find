import SwiftUI

struct RootView: View {
    @StateObject private var history = HistoryStore()

    var body: some View {
        TabView {
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .environmentObject(history)
    }
}
