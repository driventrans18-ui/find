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

        var pageReq = URLRequest(url: resultsURL)
        pageReq.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        let (pageData, _) = try await session.data(for: pageReq)
        guard let html = String(data: pageData, encoding: .utf8) else { return [] }

        return FaceURLExtractor.extractSocialURLs(from: html).map { url in
            let count = html.components(separatedBy: url.absoluteString).count - 1
            return FaceSearchResult(url: url, platform: FacePlatform.from(host: url.host ?? ""),
                                    sourceEngine: .yandex, confidence: min(0.9, 0.45 + Double(count) * 0.1))
        }
    }
}
