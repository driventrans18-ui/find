import Foundation

struct URLExtractor {
    private static let hrefPattern = try! NSRegularExpression(
        pattern: #"href=["']([^"']+)["']"#,
        options: .caseInsensitive
    )

    static func extractSocialURLs(from html: String) -> [URL] {
        var urls = Set<URL>()

        // NSDataDetector for plain URLs in text
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = detector.matches(in: html, range: range)
            for match in matches {
                if let url = match.url, isSocialURL(url) {
                    normalize(url).map { urls.insert($0) }
                }
            }
        }

        // href scraper
        let nsHTML = html as NSString
        let range = NSRange(location: 0, length: nsHTML.length)
        let matches = hrefPattern.matches(in: html, range: range)
        for match in matches {
            if match.numberOfRanges > 1 {
                let hrefRange = match.range(at: 1)
                let href = nsHTML.substring(with: hrefRange)
                if let url = URL(string: href), isSocialURL(url) {
                    normalize(url).map { urls.insert($0) }
                }
            }
        }

        return Array(urls)
    }

    static func isSocialURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return Constants.knownSocialDomains.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    static func normalize(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.query = nil
        components.fragment = nil
        // Ensure scheme is https
        if components.scheme == "http" { components.scheme = "https" }
        return components.url
    }
}
