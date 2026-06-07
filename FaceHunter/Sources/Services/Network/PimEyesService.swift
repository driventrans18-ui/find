import Foundation

final class PimEyesService: ReverseImageSearchService {
    private let session = urlSession()

    func search(imageData: Data) async throws -> [SearchResult] {
        // Step 1: Upload image to get token
        let token = try await uploadImage(imageData: imageData)

        // Step 2: Submit search
        let searchId = try await submitSearch(token: token)

        // Step 3: Poll until FINISHED
        let hits = try await pollStatus(searchId: searchId)
        return hits
    }

    private func uploadImage(imageData: Data) async throws -> String {
        let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let body = makeMultipartBody(imageData: imageData, fieldName: "file", fileName: "face.jpg", boundary: boundary)

        var request = URLRequest(url: URL(string: Constants.Network.pimEyesUploadURL)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (data, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else {
            throw PimEyesError.uploadFailed
        }
        return token
    }

    private func submitSearch(token: String) async throws -> String {
        let payload: [String: Any] = [
            "faces": [["token": token]],
            "time": "week",
            "type": "PREMIUM_SEARCH"
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: URL(string: Constants.Network.pimEyesSearchURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (data, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let searchId = json["searchId"] as? String else {
            throw PimEyesError.searchSubmitFailed
        }
        return searchId
    }

    private func pollStatus(searchId: String) async throws -> [SearchResult] {
        for attempt in 0..<Constants.Network.maxPollAttempts {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: UInt64(Constants.Network.pollInterval * 1_000_000_000))
            }

            var components = URLComponents(string: Constants.Network.pimEyesStatusURL)!
            components.queryItems = [URLQueryItem(name: "searchId", value: searchId)]

            var request = URLRequest(url: components.url!)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

            let (data, _) = try await session.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let status = json["status"] as? String ?? ""
            if status == "FINISHED", let results = json["results"] as? [[String: Any]] {
                return parseResults(results)
            }
        }
        return []
    }

    private func parseResults(_ results: [[String: Any]]) -> [SearchResult] {
        var out: [SearchResult] = []
        for item in results {
            guard let siteURL = item["siteUrl"] as? String,
                  let url = URL(string: siteURL),
                  URLExtractor.isSocialURL(url) else { continue }
            let similarity = item["similarity"] as? Double ?? 0.5
            let normalized = URLExtractor.normalize(url) ?? url
            out.append(SearchResult(
                url: normalized,
                platform: SocialPlatform.from(host: url.host ?? ""),
                sourceEngine: .pimEyes,
                confidence: similarity
            ))
        }
        return out
    }
}

enum PimEyesError: LocalizedError {
    case uploadFailed
    case searchSubmitFailed

    var errorDescription: String? {
        switch self {
        case .uploadFailed: return "PimEyes image upload failed."
        case .searchSubmitFailed: return "PimEyes search submission failed."
        }
    }
}
