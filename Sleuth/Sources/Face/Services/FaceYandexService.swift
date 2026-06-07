import Foundation

final class FaceYandexService {
    private let session = faceURLSession()

    func search(imageData: Data) async throws -> [FaceSearchResult] {
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var components = URLComponents(string: "https://yandex.com/images/search")!
        components.queryItems = [URLQueryItem(name: "rpt", value: "imageview"), URLQueryItem(name: "format", value: "json")]

        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = faceMultipartBody(imageData: imageData, field: "upfile", fileName: "face.jpg", boundary: boundary)

        let (uploadData, _) = try await session.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: uploadData) as? [String: Any],
              let urlStr = json["url"] as? String,
              let resultsURL = URL(string: urlStr) else { return [] }

        let html = (try? await fetchHTMLWithBrowser(url: resultsURL, waitAfterLoad: 2.0)) ?? ""
        guard !html.isEmpty else { return [] }

        return parseYandexHTML(html)
    }

    private func parseYandexHTML(_ html: String) -> [FaceSearchResult] {
        let ns = html as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        // Collect result thumbnail images
        let imgPattern = try! NSRegularExpression(
            pattern: #"<img[^>]+src=["'](https?://[^"']{20,})["'][^>]*>"#,
            options: .caseInsensitive
        )
        struct Pos { let loc: Int; let value: String }
        var imgEntries: [Pos] = []
        imgPattern.matches(in: html, range: fullRange).forEach { m in
            guard m.numberOfRanges > 1 else { return }
            let src = ns.substring(with: m.range(at: 1))
            let low = src.lowercased()
            guard !low.contains("yastatic") || low.contains("thumb") || low.contains("orig") else { return }
            imgEntries.append(Pos(loc: m.range.location, value: src))
        }

        var results: [FaceSearchResult] = []
        var seen = Set<String>()

        for url in FaceURLExtractor.extractAllURLs(from: html) {
            let urlStr = url.absoluteString
            guard seen.insert(urlStr).inserted else { continue }

            let linkLoc = ns.range(of: urlStr).location
            let thumbURL: URL? = imgEntries
                .filter { abs($0.loc - (linkLoc == NSNotFound ? 0 : linkLoc)) < 3000 }
                .min(by: { abs($0.loc - linkLoc) < abs($1.loc - linkLoc) })
                .flatMap { URL(string: $0.value) }

            let count = html.components(separatedBy: urlStr).count - 1
            results.append(FaceSearchResult(
                url: url,
                platform: FacePlatform.from(host: url.host ?? ""),
                sourceEngine: .yandex,
                confidence: min(0.9, 0.45 + Double(count) * 0.1),
                thumbnailURL: thumbURL
            ))
        }
        return results
    }
}
