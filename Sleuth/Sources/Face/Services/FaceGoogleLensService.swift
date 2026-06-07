import Foundation

final class FaceGoogleLensService {
    private let delegate = NoRedirectDelegate()
    private lazy var noRedirectSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

    // Returns the Google Lens results URL after uploading.
    func uploadAndGetResultURL(imageData: Data) async -> URL? {
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var req = URLRequest(url: URL(string: "https://lens.google.com/upload")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://lens.google.com/", forHTTPHeaderField: "Referer")
        req.httpBody = faceMultipartBody(imageData: imageData, field: "encoded_image", fileName: "face.jpg", boundary: boundary)
        guard let (_, uploadResponse) = try? await noRedirectSession.data(for: req) else { return nil }
        if let http = uploadResponse as? HTTPURLResponse,
           let loc = http.allHeaderFields["Location"] as? String,
           let u = URL(string: loc) { return u }
        if let u = uploadResponse.url, !u.absoluteString.contains("/upload") { return u }
        return nil
    }

    // Legacy full search
    func search(imageData: Data) async throws -> [FaceSearchResult] {
        guard let url = await uploadAndGetResultURL(imageData: imageData) else { return [] }
        let html = (try? await fetchHTMLWithBrowser(url: url, waitAfterLoad: 2.5)) ?? ""
        guard !html.isEmpty else { return [] }
        return FaceURLExtractor.extractAllURLs(from: html).map { u in
            let count = html.components(separatedBy: u.absoluteString).count - 1
            return FaceSearchResult(url: u, platform: FacePlatform.from(host: u.host ?? ""),
                                    sourceEngine: .googleLens, confidence: min(0.95, 0.5 + Double(count) * 0.1))
        }
    }
}

final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? { nil }
}
