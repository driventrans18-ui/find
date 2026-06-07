import SwiftUI

@main
struct FaceHunterApp: App {
    private let deps = AppDependencies.live

    var body: some Scene {
        WindowGroup {
            HomeView(deps: deps)
                .preferredColorScheme(.dark)
        }
    }
}
