import Foundation

struct SearchResult: Identifiable, Codable, Hashable {
    let id: UUID
    let url: URL
    let platform: SocialPlatform
    let sourceEngine: SearchEngine
    let confidence: Double
    let title: String?
    let thumbnailURL: URL?
    let discoveredAt: Date

    init(
        id: UUID = UUID(),
        url: URL,
        platform: SocialPlatform,
        sourceEngine: SearchEngine,
        confidence: Double,
        title: String? = nil,
        thumbnailURL: URL? = nil,
        discoveredAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.platform = platform
        self.sourceEngine = sourceEngine
        self.confidence = confidence
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.discoveredAt = discoveredAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url.absoluteString)
    }

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.url.absoluteString == rhs.url.absoluteString
    }
}

enum SocialPlatform: String, Codable, CaseIterable {
    case facebook
    case instagram
    case twitter
    case linkedin
    case tiktok
    case youtube
    case pinterest
    case reddit
    case vk
    case ok
    case snapchat
    case tumblr
    case flickr
    case behance
    case github
    case unknown

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

    static func from(host: String) -> SocialPlatform {
        let lower = host.lowercased()
        if lower.contains("facebook") || lower.contains("fb.com") { return .facebook }
        if lower.contains("instagram") { return .instagram }
        if lower.contains("twitter") || lower.contains("x.com") { return .twitter }
        if lower.contains("linkedin") { return .linkedin }
        if lower.contains("tiktok") { return .tiktok }
        if lower.contains("youtube") || lower.contains("youtu.be") { return .youtube }
        if lower.contains("pinterest") { return .pinterest }
        if lower.contains("reddit") { return .reddit }
        if lower.contains("vk.com") || lower.contains("vkontakte") { return .vk }
        if lower.contains("ok.ru") { return .ok }
        if lower.contains("snapchat") { return .snapchat }
        if lower.contains("tumblr") { return .tumblr }
        if lower.contains("flickr") { return .flickr }
        if lower.contains("behance") { return .behance }
        if lower.contains("github") { return .github }
        return .unknown
    }
}
