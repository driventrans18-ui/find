import SwiftUI

struct RootView: View {
    @StateObject private var history = HistoryStore()

    var body: some View {
        TabView {
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            FaceSearchView()
                .tabItem { Label("Face", systemImage: "face.smiling") }

            TelegramSearchView()
                .tabItem { Label("Telegram", systemImage: "paperplane.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .environmentObject(history)
    }
}
