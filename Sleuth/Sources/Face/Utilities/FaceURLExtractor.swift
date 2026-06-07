import Foundation

struct FaceURLExtractor {
    private static let hrefRegex = try! NSRegularExpression(pattern: #"href=["']([^"']+)["']"#, options: .caseInsensitive)

    static let socialDomains = [
        "facebook.com", "fb.com", "instagram.com", "twitter.com", "x.com",
        "linkedin.com", "tiktok.com", "youtube.com", "youtu.be", "pinterest.com",
        "reddit.com", "vk.com", "ok.ru", "snapchat.com", "tumblr.com",
        "flickr.com", "behance.net", "github.com"
    ]

    // Strict filter — only known social domains
    static func extractSocialURLs(from html: String) -> [URL] {
        extractAllURLs(from: html).filter { isSocial($0) }
    }

    // Broader filter — any external https URL that looks like a profile page
    static func extractAllURLs(from html: String) -> [URL] {
        var urls = Set<URL>()

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            detector.matches(in: html, range: NSRange(html.startIndex..., in: html)).forEach {
                if let url = $0.url, isUseful(url), let n = normalize(url) { urls.insert(n) }
            }
        }

        let ns = html as NSString
        hrefRegex.matches(in: html, range: NSRange(location: 0, length: ns.length)).forEach {
            if $0.numberOfRanges > 1,
               let url = URL(string: ns.substring(with: $0.range(at: 1))),
               isUseful(url), let n = normalize(url) { urls.insert(n) }
        }

        return Array(urls)
    }

    static func isSocial(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return socialDomains.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    static func normalize(_ url: URL) -> URL? {
        guard var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        c.query = nil; c.fragment = nil
        if c.scheme == "http" { c.scheme = "https" }
        return c.url
    }

    // Exclude noise: google-internal URLs, javascript, anchors, CDN assets
    private static func isUseful(_ url: URL) -> Bool {
        guard let scheme = url.scheme, scheme == "https" || scheme == "http",
              let host = url.host else { return false }
        let h = host.lowercased()
        let blocklist = ["google.com", "gstatic.com", "googleapis.com", "googleusercontent.com",
                         "yandex.ru", "yandex.com", "yandex.net", "pimeyes.com",
                         "apple.com", "icloud.com", "w3.org", "schema.org"]
        if blocklist.contains(where: { h == $0 || h.hasSuffix(".\($0)") }) { return false }
        // Must have a path that looks like a profile (not just a root domain)
        let path = url.path
        return path.count > 1
    }
}
