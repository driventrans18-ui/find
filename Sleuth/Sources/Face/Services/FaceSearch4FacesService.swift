import Foundation

final class FaceSearch4FacesService {
    private let session = faceURLSession()

    func search(imageData: Data) async throws -> [FaceSearchResult] {
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var req = URLRequest(url: URL(string: "https://search4faces.com/tt00/index.html")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://search4faces.com/", forHTTPHeaderField: "Referer")
        req.httpBody = faceMultipartBody(imageData: imageData, field: "file", fileName: "face.jpg", boundary: boundary)

        let (data, response) = try await session.data(for: req)

        // Search4Faces may redirect to a results page
        let html: String
        if let h = String(data: data, encoding: .utf8), h.contains("result") {
            html = h
        } else if let resultsURL = (response as? HTTPURLResponse).flatMap({ _ in response.url }),
                  resultsURL.absoluteString != "https://search4faces.com/tt00/index.html" {
            var pageReq = URLRequest(url: resultsURL)
            pageReq.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
            let (pageData, _) = try await session.data(for: pageReq)
            guard let h = String(data: pageData, encoding: .utf8) else { return [] }
            html = h
        } else {
            guard let h = String(data: data, encoding: .utf8) else { return [] }
            html = h
        }

        return parseResults(from: html)
    }

    private func parseResults(from html: String) -> [FaceSearchResult] {
        // Search4Faces returns links to VK/OK profiles directly in the results HTML
        var results: [FaceSearchResult] = []

        // Extract profile links — Search4Faces links to vk.com and ok.ru profiles
        let profilePattern = try! NSRegularExpression(
            pattern: #"href=["'](https?://(?:vk\.com|ok\.ru|m\.vk\.com)/[^"'\s>]+)["']"#,
            options: .caseInsensitive
        )
        let ns = html as NSString
        let matches = profilePattern.matches(in: html, range: NSRange(location: 0, length: ns.length))

        var seen = Set<String>()
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let urlStr = ns.substring(with: match.range(at: 1))
            guard seen.insert(urlStr).inserted, let url = URL(string: urlStr),
                  let norm = FaceURLExtractor.normalize(url) else { continue }
            results.append(FaceSearchResult(
                url: norm,
                platform: FacePlatform.from(host: url.host ?? ""),
                sourceEngine: .search4faces,
                confidence: 0.7
            ))
        }

        // Also run general extractor as fallback
        if results.isEmpty {
            results = FaceURLExtractor.extractAllURLs(from: html).map {
                FaceSearchResult(url: $0, platform: FacePlatform.from(host: $0.host ?? ""),
                                 sourceEngine: .search4faces, confidence: 0.6)
            }
        }

        return results
    }
}
