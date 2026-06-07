import Foundation

enum SearchEngine: String, Codable, CaseIterable, Identifiable {
    case googleLens = "Google Lens"
    case yandex = "Yandex"
    case pimEyes = "PimEyes"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .googleLens: return "magnifyingglass.circle.fill"
        case .yandex: return "y.square.fill"
        case .pimEyes: return "eye.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .googleLens: return "engineGoogle"
        case .yandex: return "engineYandex"
        case .pimEyes: return "enginePimEyes"
        }
    }
}
