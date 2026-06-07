import Foundation

final class GoogleLensService: ReverseImageSearchService {
    private let session = urlSession()

    func search(imageData: Data) async throws -> [SearchResult] {
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let body = makeMultipartBody(imageData: imageData, fieldName: "encoded_image", fileName: "face.jpg", boundary: boundary)

        var request = URLRequest(url: URL(string: Constants.Network.googleLensUploadURL)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { return [] }

        // After upload, Google Lens redirects to the results page
        let resultsURL: URL
        if let location = httpResponse.allHeaderFields["Location"] as? String,
           let loc = URL(string: location) {
            resultsURL = loc
        } else if let finalURL = (response as? HTTPURLResponse).flatMap({ _ in
            // Some URLSession configurations follow redirects automatically
            response.url
        }), finalURL.absoluteString.contains("lens.google.com") {
            resultsURL = finalURL
        } else {
            return []
        }

        var pageRequest = URLRequest(url: resultsURL)
        pageRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        let (pageData, _) = try await session.data(for: pageRequest)
        guard let html = String(data: pageData, encoding: .utf8) else { return [] }

        let socialURLs = URLExtractor.extractSocialURLs(from: html)
        return socialURLs.map { url in
            SearchResult(
                url: url,
                platform: SocialPlatform.from(host: url.host ?? ""),
                sourceEngine: .googleLens,
                confidence: confidenceScore(for: url, in: html)
            )
        }
    }

    private func confidenceScore(for url: URL, in html: String) -> Double {
        let urlStr = url.absoluteString
        let occurrences = html.components(separatedBy: urlStr).count - 1
        return min(0.95, 0.5 + Double(occurrences) * 0.1)
    }
}
