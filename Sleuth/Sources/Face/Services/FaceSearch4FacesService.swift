import Foundation

final class FaceSearch4FacesService {
    private let session = faceURLSession()

    // Primary and fallback endpoints
    private let endpoints = [
        "https://search4faces.com/",
        "https://search4faces.com/en/"
    ]

    func search(imageData: Data) async throws -> [FaceSearchResult] {
        // Try WKWebView browser submission first (bypasses bot detection)
        for endpoint in endpoints {
            guard let pageURL = URL(string: endpoint) else { continue }
            if let html = try? await submitImageFormWithBrowser(pageURL: pageURL, imageData: imageData, waitAfterSubmit: 7.0),
               !html.isEmpty {
                let results = parseResults(from: html)
                if !results.isEmpty { return results }
            }
        }
        // Fallback: plain URLSession upload
        for endpoint in endpoints {
            let results = (try? await attemptSearch(imageData: imageData, endpoint: endpoint)) ?? []
            if !results.isEmpty { return results }
        }
        return []
    }

    // MARK: - Private

    private func attemptSearch(imageData: Data, endpoint: String) async throws -> [FaceSearchResult] {
        guard let url = URL(string: endpoint) else { return [] }
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(endpoint, forHTTPHeaderField: "Referer")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        req.httpBody = faceMultipartBody(imageData: imageData, field: "photo", fileName: "face.jpg", boundary: boundary)

        let (data, _) = try await session.data(for: req)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return []
        }

        return parseResults(from: html)
    }

    private func parseResults(from html: String) -> [FaceSearchResult] {
        let ns = html as NSString

        // Match result blocks: look for img tags paired with nearby profile anchors.
        // Search4Faces HTML structure example:
        //   <div class="item">
        //     <img src="/img/result/XXXXX.jpg">
        //     <a href="https://vk.com/id123456">...</a>
        //   </div>

        // Step 1: Find all result items as raw HTML chunks split by common container boundaries.
        // We'll use a two-pass approach: first gather all (thumbnailSrc, profileHref) pairs.

        // Regex for vk.com / ok.ru profile links only
        let profilePattern = try! NSRegularExpression(
            pattern: #"href=["'](https?://(?:(?:www\.)?vk\.com|(?:www\.)?m\.vk\.com|(?:www\.)?ok\.ru)/[A-Za-z0-9_.@/?=-]+)["']"#,
            options: .caseInsensitive
        )

        // Regex for result thumbnail images (relative /img/result/ paths or absolute https)
        let imgPattern = try! NSRegularExpression(
            pattern: #"<img[^>]+src=["']([^"']+)["'][^>]*>"#,
            options: .caseInsensitive
        )

        let fullRange = NSRange(location: 0, length: ns.length)

        // Collect all img src positions and values
        struct ImgEntry { let range: NSRange; let src: String }
        var imgEntries: [ImgEntry] = []
        imgPattern.matches(in: html, range: fullRange).forEach { m in
            guard m.numberOfRanges > 1 else { return }
            let src = ns.substring(with: m.range(at: 1))
            // Only keep result images, not logos/icons (result images typically under /img/result/ or external http)
            let srcLow = src.lowercased()
            // Exclude obviously non-result images
            let skipPrefixes = ["/img/logo", "/img/icon", "/img/bg", "/css/", "/js/", "data:"]
            if skipPrefixes.contains(where: { srcLow.hasPrefix($0) }) { return }
            imgEntries.append(ImgEntry(range: m.range, src: src))
        }

        // Collect all profile link positions and values
        struct LinkEntry { let range: NSRange; let href: String }
        var linkEntries: [LinkEntry] = []
        profilePattern.matches(in: html, range: fullRange).forEach { m in
            guard m.numberOfRanges > 1 else { return }
            linkEntries.append(LinkEntry(range: m.range, href: ns.substring(with: m.range(at: 1))))
        }

        guard !linkEntries.isEmpty else { return [] }

        // Step 2: For each profile link, find the nearest preceding img src within 1000 chars
        var results: [FaceSearchResult] = []
        var seen = Set<String>()

        for link in linkEntries {
            guard seen.insert(link.href).inserted else { continue }
            guard let profileURL = URL(string: link.href),
                  let normalizedURL = FaceURLExtractor.normalize(profileURL) else { continue }

            // Find nearest img that appears before or slightly after the link (within 1200 chars)
            let linkLoc = link.range.location
            let nearbyImg = imgEntries.min(by: {
                abs($0.range.location - linkLoc) < abs($1.range.location - linkLoc)
            }).flatMap { entry -> URL? in
                // Only use if within 1200 characters of the link
                guard abs(entry.range.location - linkLoc) < 1200 else { return nil }
                var src = entry.src
                // Resolve relative URLs
                if src.hasPrefix("/") {
                    src = "https://search4faces.com\(src)"
                }
                return URL(string: src)
            }

            results.append(FaceSearchResult(
                url: normalizedURL,
                platform: FacePlatform.from(host: profileURL.host ?? ""),
                sourceEngine: .search4faces,
                confidence: 0.75,
                thumbnailURL: nearbyImg
            ))
        }

        return results
    }
}
