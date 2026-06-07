import SwiftUI

@main
struct SleuthApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    // Load cached/bundled data first so `SiteCatalog.all` is
                    // populated, then fetch the latest Sherlock database.
                    await SherlockCatalog.shared.load()
                    await SherlockCatalog.shared.refresh()
                }
        }
    }
}
