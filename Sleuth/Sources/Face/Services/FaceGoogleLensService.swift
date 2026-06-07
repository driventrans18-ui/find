import Foundation

final class FaceGoogleLensService {
    private let delegate = NoRedirectDelegate()
    private lazy var noRedirectSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

    func search(imageData: Data) async throws -> [FaceSearchResult] {
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        var req = URLRequest(url: URL(string: "https://lens.google.com/upload")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://lens.google.com/", forHTTPHeaderField: "Referer")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        req.httpBody = faceMultipartBody(imageData: imageData, field: "encoded_image", fileName: "face.jpg", boundary: boundary)

        let (_, uploadResponse) = try await noRedirectSession.data(for: req)

        let resultsURL: URL
        if let http = uploadResponse as? HTTPURLResponse,
           let loc = http.allHeaderFields["Location"] as? String,
           let u = URL(string: loc) {
            resultsURL = u
        } else if let u = uploadResponse.url, !u.absoluteString.contains("/upload") {
            resultsURL = u
        } else {
            return []
        }

        let html = (try? await fetchHTMLWithBrowser(url: resultsURL, waitAfterLoad: 2.5)) ?? ""
        guard !html.isEmpty else { return [] }

        return parseGoogleLensHTML(html)
    }

    private func parseGoogleLensHTML(_ html: String) -> [FaceSearchResult] {
        let ns = html as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        // Collect img srcs (result thumbnails)
        let imgPattern = try! NSRegularExpression(
            pattern: #"<img[^>]+src=["'](https?://[^"']{20,})["'][^>]*>"#,
            options: .caseInsensitive
        )
        struct Pos { let loc: Int; let value: String }
        var imgEntries: [Pos] = []
        imgPattern.matches(in: html, range: fullRange).forEach { m in
            guard m.numberOfRanges > 1 else { return }
            let src = ns.substring(with: m.range(at: 1))
            // Skip Google UI chrome, keep result images
            let low = src.lowercased()
            guard !low.contains("google.com/images/branding"),
                  !low.contains("gstatic.com/images/icons"),
                  !low.contains("maps.gstatic") else { return }
            imgEntries.append(Pos(loc: m.range.location, value: src))
        }

        var results: [FaceSearchResult] = []
        var seen = Set<String>()

        for url in FaceURLExtractor.extractAllURLs(from: html) {
            let urlStr = url.absoluteString
            guard seen.insert(urlStr).inserted else { continue }

            // Find nearest thumbnail
            let linkLoc = (html as NSString).range(of: urlStr).location
            let thumbURL: URL? = imgEntries
                .filter { abs($0.loc - (linkLoc == NSNotFound ? 0 : linkLoc)) < 3000 }
                .min(by: { abs($0.loc - linkLoc) < abs($1.loc - linkLoc) })
                .flatMap { URL(string: $0.value) }

            let count = html.components(separatedBy: urlStr).count - 1
            results.append(FaceSearchResult(
                url: url,
                platform: FacePlatform.from(host: url.host ?? ""),
                sourceEngine: .googleLens,
                confidence: min(0.95, 0.5 + Double(count) * 0.1),
                thumbnailURL: thumbURL
            ))
        }
        return results
    }
}

final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        return nil
    }
}
