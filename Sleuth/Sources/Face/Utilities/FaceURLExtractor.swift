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

    // Exclude noise: CDN/script/asset URLs and known tracker/infrastructure domains
    private static func isUseful(_ url: URL) -> Bool {
        guard let scheme = url.scheme, scheme == "https" || scheme == "http",
              let host = url.host else { return false }
        let h = host.lowercased()

        // Block known infrastructure / CDN / analytics / search engine domains
        let blockedDomains = [
            "google.com", "gstatic.com", "googleapis.com", "googleusercontent.com",
            "googletagmanager.com", "google-analytics.com", "doubleclick.net",
            "googlesyndication.com", "googleadservices.com",
            "yandex.ru", "yandex.com", "yandex.net",
            "pimeyes.com",
            "apple.com", "icloud.com",
            "w3.org", "schema.org",
            "cloudflare.com", "cloudflareinsights.com",
            "jquery.com", "jquery.org",
            "unpkg.com", "jsdelivr.net",
            "bootstrapcdn.com",
            "search4faces.com",
            "amazon.com", "amazonaws.com",
            "akamai.com", "akamaized.net", "akamaihd.net",
            "fastly.net", "fastly.com",
            "cdnjs.cloudflare.com",
            "twimg.com",
            "fbcdn.net", "fbsbx.com",
            "instagram.fbcdn.net",
            "cookiebot.com", "onfastspring.com", "optimizely.com", "hotjar.com",
            "intercom.io", "zendesk.com", "hubspot.com", "salesforce.com",
            "marketo.com", "pardot.com", "eloqua.com", "drift.com",
            "segment.io", "segment.com", "mixpanel.com", "amplitude.com",
            "heap.io", "fullstory.com", "logrocket.com", "sentry.io",
            "rollbar.com", "newrelic.com", "datadog.com", "pingdom.com",
            "statuspage.io"
        ]
        if blockedDomains.contains(where: { h == $0 || h.hasSuffix(".\($0)") }) { return false }

        // Block deep CDN subdomains (more than 3 dots in host = likely cdn-123.something.net.example.com)
        if h.components(separatedBy: ".").count > 4 { return false }

        // Block CDN-pattern .net domains: subdomain(s) containing digits before the TLD
        if h.hasSuffix(".net") {
            let parts = h.components(separatedBy: ".")
            // If any subdomain label (not the SLD or TLD) is short and contains digits, treat as CDN
            if parts.count >= 3 {
                let subdomains = parts.dropLast(2)
                if subdomains.contains(where: { $0.count <= 6 && $0.contains(where: { $0.isNumber }) }) {
                    return false
                }
            }
        }

        // Block static asset extensions
        let path = url.path.lowercased()
        let blockedExtensions = [".js", ".css", ".woff", ".woff2", ".ttf", ".eot",
                                  ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico",
                                  ".webp", ".mp4", ".mp3", ".pdf", ".zip", ".map"]
        if blockedExtensions.contains(where: { path.hasSuffix($0) }) { return false }

        // Must have a meaningful path (more than just "/" or "/a")
        return path.count > 2
    }
}
