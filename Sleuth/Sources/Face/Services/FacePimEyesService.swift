import Foundation

final class FacePimEyesService {
    private let session = faceURLSession()

    func search(imageData: Data) async throws -> [FaceSearchResult] {
        let token = try await upload(imageData: imageData)
        let searchId = try await submit(token: token)
        return try await poll(searchId: searchId)
    }

    private func upload(imageData: Data) async throws -> String {
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var req = URLRequest(url: URL(string: "https://pimeyes.com/api/upload/file")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = faceMultipartBody(imageData: imageData, field: "file", fileName: "face.jpg", boundary: boundary)

        let (data, _) = try await session.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else { throw FacePimEyesError.uploadFailed }
        return token
    }

    private func submit(token: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: [
            "faces": [["token": token]], "time": "week", "type": "PREMIUM_SEARCH"
        ])
        var req = URLRequest(url: URL(string: "https://pimeyes.com/api/search/new")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = body

        let (data, _) = try await session.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["searchId"] as? String else { throw FacePimEyesError.submitFailed }
        return id
    }

    private func poll(searchId: String) async throws -> [FaceSearchResult] {
        for attempt in 0..<15 {
            if attempt > 0 { try await Task.sleep(nanoseconds: 2_000_000_000) }
            var c = URLComponents(string: "https://pimeyes.com/api/search/status")!
            c.queryItems = [URLQueryItem(name: "searchId", value: searchId)]
            var req = URLRequest(url: c.url!)
            req.setValue(faceUserAgent, forHTTPHeaderField: "User-Agent")

            let (data, _) = try await session.data(for: req)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if json["status"] as? String == "FINISHED",
               let items = json["results"] as? [[String: Any]] {
                return items.compactMap { item -> FaceSearchResult? in
                    guard let siteURL = item["siteUrl"] as? String,
                          let url = URL(string: siteURL),
                          FaceURLExtractor.isSocial(url),
                          let norm = FaceURLExtractor.normalize(url) else { return nil }
                    return FaceSearchResult(url: norm, platform: FacePlatform.from(host: url.host ?? ""),
                                            sourceEngine: .pimEyes, confidence: item["similarity"] as? Double ?? 0.5)
                }
            }
        }
        return []
    }
}

enum FacePimEyesError: LocalizedError {
    case uploadFailed, submitFailed
    var errorDescription: String? {
        switch self { case .uploadFailed: return "PimEyes upload failed."; case .submitFailed: return "PimEyes search failed." }
    }
}
