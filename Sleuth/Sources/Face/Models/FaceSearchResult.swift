import Foundation

struct FaceSearchResult: Identifiable, Codable, Hashable {
    let id: UUID
    let url: URL
    let platform: FacePlatform
    let sourceEngine: FaceEngine
    let confidence: Double
    let discoveredAt: Date

    init(id: UUID = UUID(), url: URL, platform: FacePlatform, sourceEngine: FaceEngine, confidence: Double, discoveredAt: Date = Date()) {
        self.id = id
        self.url = url
        self.platform = platform
        self.sourceEngine = sourceEngine
        self.confidence = confidence
        self.discoveredAt = discoveredAt
    }

    func hash(into hasher: inout Hasher) { hasher.combine(url.absoluteString) }
    static func == (lhs: FaceSearchResult, rhs: FaceSearchResult) -> Bool { lhs.url.absoluteString == rhs.url.absoluteString }
}

enum FacePlatform: String, Codable, CaseIterable {
    case facebook, instagram, twitter, linkedin, tiktok, youtube, pinterest, reddit, vk, ok, snapchat, tumblr, flickr, behance, github, unknown

    var displayName: String {
        switch self {
        case .facebook: return "Facebook"
        case .instagram: return "Instagram"
        case .twitter: return "Twitter / X"
        case .linkedin: return "LinkedIn"
        case .tiktok: return "TikTok"
        case .youtube: return "YouTube"
        case .pinterest: return "Pinterest"
        case .reddit: return "Reddit"
        case .vk: return "VK"
        case .ok: return "OK"
        case .snapchat: return "Snapchat"
        case .tumblr: return "Tumblr"
        case .flickr: return "Flickr"
        case .behance: return "Behance"
        case .github: return "GitHub"
        case .unknown: return "Web"
        }
    }

    var sfSymbol: String {
        switch self {
        case .facebook: return "person.2.fill"
        case .instagram: return "camera.fill"
        case .twitter: return "bird.fill"
        case .linkedin: return "briefcase.fill"
        case .tiktok: return "music.note"
        case .youtube: return "play.rectangle.fill"
        case .pinterest: return "pin.fill"
        case .reddit: return "bubble.left.and.bubble.right.fill"
        case .vk: return "v.square.fill"
        case .ok: return "circle.grid.cross.fill"
        case .snapchat: return "message.fill"
        case .tumblr: return "t.square.fill"
        case .flickr: return "photo.fill"
        case .behance: return "b.square.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .unknown: return "globe"
        }
    }

    static func from(host: String) -> FacePlatform {
        let h = host.lowercased()
        if h.contains("facebook") || h.contains("fb.com") { return .facebook }
        if h.contains("instagram") { return .instagram }
        if h.contains("twitter") || h.contains("x.com") { return .twitter }
        if h.contains("linkedin") { return .linkedin }
        if h.contains("tiktok") { return .tiktok }
        if h.contains("youtube") || h.contains("youtu.be") { return .youtube }
        if h.contains("pinterest") { return .pinterest }
        if h.contains("reddit") { return .reddit }
        if h.contains("vk.com") { return .vk }
        if h.contains("ok.ru") { return .ok }
        if h.contains("snapchat") { return .snapchat }
        if h.contains("tumblr") { return .tumblr }
        if h.contains("flickr") { return .flickr }
        if h.contains("behance") { return .behance }
        if h.contains("github") { return .github }
        return .unknown
    }
}

enum FaceEngine: String, Codable, CaseIterable, Identifiable {
    case googleLens = "Google Lens"
    case yandex = "Yandex"
    case pimEyes = "PimEyes"
    case search4faces = "Search4Faces"
    var id: String { rawValue }
}
