import Foundation

final class YandexService: ReverseImageSearchService {
    private let session = urlSession()

    func search(imageData: Data) async throws -> [SearchResult] {
        // Step 1: Upload image
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let body = makeMultipartBody(imageData: imageData, fieldName: "upfile", fileName: "face.jpg", boundary: boundary)

        var uploadURL = URLComponents(string: Constants.Network.yandexSearchURL)!
        uploadURL.queryItems = [
            URLQueryItem(name: "rpt", value: "imageview"),
            URLQueryItem(name: "format", value: "json")
        ]

        var request = URLRequest(url: uploadURL.url!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (uploadData, _) = try await session.data(for: request)

        // Step 2: Parse JSON to get results page URL
        guard let json = try? JSONSerialization.jsonObject(with: uploadData) as? [String: Any],
              let urlStr = json["url"] as? String,
              let resultsURL = URL(string: urlStr) else {
            return []
        }

        // Step 3: Fetch results page
        var pageRequest = URLRequest(url: resultsURL)
        pageRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        let (pageData, _) = try await session.data(for: pageRequest)
        guard let html = String(data: pageData, encoding: .utf8) else { return [] }

        let socialURLs = URLExtractor.extractSocialURLs(from: html)
        return socialURLs.map { url in
            SearchResult(
                url: url,
                platform: SocialPlatform.from(host: url.host ?? ""),
                sourceEngine: .yandex,
                confidence: confidenceScore(for: url, in: html)
            )
        }
    }

    private func confidenceScore(for url: URL, in html: String) -> Double {
        let urlStr = url.absoluteString
        let occurrences = html.components(separatedBy: urlStr).count - 1
        return min(0.9, 0.45 + Double(occurrences) * 0.1)
    }
}
