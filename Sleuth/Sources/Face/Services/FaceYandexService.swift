import Foundation

final class FaceYandexService {
    private let session = faceURLSession()

    // Returns the Yandex reverse image search results URL after uploading.
    func uploadAndGetResultURL(imageData: Data) async -> URL? {
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var components = URLComponents(string: "https://yandex.com/images/search")!
        components.queryItems = [URLQueryItem(name: "rpt", value: "imageview"),
                                 URLQueryItem(name: "format", value: "json")]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = faceMultipartBody(imageData: imageData, field: "upfile", fileName: "face.jpg", boundary: boundary)
        guard let (uploadData, _) = try? await session.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: uploadData) as? [String: Any],
              let urlStr = json["url"] as? String,
              let url = URL(string: urlStr) else { return nil }
        return url
    }

    // Legacy full search (kept for compatibility)
    func search(imageData: Data) async throws -> [FaceSearchResult] {
        guard let url = await uploadAndGetResultURL(imageData: imageData) else { return [] }
        let html = (try? await fetchHTMLWithBrowser(url: url, waitAfterLoad: 2.0)) ?? ""
        guard !html.isEmpty else { return [] }
        return FaceURLExtractor.extractAllURLs(from: html).map { u in
            let count = html.components(separatedBy: u.absoluteString).count - 1
            return FaceSearchResult(url: u, platform: FacePlatform.from(host: u.host ?? ""),
                                    sourceEngine: .yandex, confidence: min(0.9, 0.45 + Double(count) * 0.1))
        }
    }
}
