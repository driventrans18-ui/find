import Foundation

struct AppDependencies {
    let googleLens: ReverseImageSearchService
    let yandex: ReverseImageSearchService
    let pimEyes: ReverseImageSearchService
    let sessionStore: SessionStore

    static let live = AppDependencies(
        googleLens: GoogleLensService(),
        yandex: YandexService(),
        pimEyes: PimEyesService(),
        sessionStore: SessionStore.shared
    )
}
