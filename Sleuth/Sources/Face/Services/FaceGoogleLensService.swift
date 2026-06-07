import Foundation

final class FaceGoogleLensService {
    // Delegate captures the redirect URL instead of following it automatically
    private let delegate = NoRedirectDelegate()
    private lazy var noRedirectSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    private let session = faceURLSession()

    func search(imageData: Data) async throws -> [FaceSearchResult] {
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        var req = URLRequest(url: URL(string: "https://lens.google.com/upload")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://lens.google.com/", forHTTPHeaderField: "Referer")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        req.httpBody = faceMultipartBody(imageData: imageData, field: "encoded_image", fileName: "face.jpg", boundary: boundary)

        // Upload — the delegate stops the redirect so response.url is the Location target
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

        var pageReq = URLRequest(url: resultsURL)
        pageReq.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        pageReq.setValue("https://lens.google.com/", forHTTPHeaderField: "Referer")
        let (data, _) = try await session.data(for: pageReq)
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        return FaceURLExtractor.extractAllURLs(from: html).map { url in
            let count = html.components(separatedBy: url.absoluteString).count - 1
            return FaceSearchResult(url: url, platform: FacePlatform.from(host: url.host ?? ""),
                                    sourceEngine: .googleLens, confidence: min(0.95, 0.5 + Double(count) * 0.1))
        }
    }
}

final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        return nil // don't follow redirect; let us capture the Location header
    }
}
