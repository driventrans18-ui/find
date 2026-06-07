import Foundation

final class FaceGoogleLensService {
    private let session = faceURLSession()

    func search(imageData: Data) async throws -> [FaceSearchResult] {
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var req = URLRequest(url: URL(string: "https://lens.google.com/upload")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = faceMultipartBody(imageData: imageData, field: "encoded_image", fileName: "face.jpg", boundary: boundary)

        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { return [] }

        let resultsURL: URL
        if let loc = http.allHeaderFields["Location"] as? String, let u = URL(string: loc) {
            resultsURL = u
        } else if let u = response.url, u.absoluteString.contains("lens.google.com") {
            resultsURL = u
        } else { return [] }

        var pageReq = URLRequest(url: resultsURL)
        pageReq.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: pageReq)
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        return FaceURLExtractor.extractSocialURLs(from: html).map { url in
            let count = html.components(separatedBy: url.absoluteString).count - 1
            return FaceSearchResult(url: url, platform: FacePlatform.from(host: url.host ?? ""),
                                    sourceEngine: .googleLens, confidence: min(0.95, 0.5 + Double(count) * 0.1))
        }
    }
}
