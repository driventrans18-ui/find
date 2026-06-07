import Foundation

/// Probes sites concurrently to determine whether a username exists.
///
/// Detection mirrors Sherlock's approach: a site declares either a
/// status-code rule (404 → absent) or an error-message rule (a marker string
/// in the body → absent). We send a desktop-ish User-Agent because several
/// networks return 403/empty bodies to default client agents.
actor UsernameChecker {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 12
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/json;q=0.9,*/*;q=0.8"
        ]
        session = URLSession(configuration: config)
    }

    /// Probe sites concurrently in batches to avoid overwhelming the network stack.
    /// The `onResult` closure is invoked on the main actor.
    func search(
        username: String,
        sites: [SiteTarget],
        onResult: @MainActor @escaping (SearchResult) -> Void
    ) async {
        let plausible = sites.filter { $0.isPlausible(username: username) }
        let batchSize = 40
        var idx = 0
        while idx < plausible.count {
            let batch = Array(plausible[idx..<min(idx + batchSize, plausible.count)])
            idx += batchSize
            await withTaskGroup(of: SearchResult.self) { group in
                for site in batch {
                    group.addTask { await self.check(username: username, site: site) }
                }
                for await result in group {
                    await onResult(result)
                }
            }
        }
    }

    private func check(username: String, site: SiteTarget) async -> SearchResult {
        guard let probeURL = site.probeURL(for: username) else {
            return SearchResult(site: site, username: username,
                                status: .error("Bad URL"), profileURL: nil)
        }
        let profileURL = site.profileURL(for: username)

        var request = URLRequest(url: probeURL)
        request.httpMethod = site.detection == .statusCode ? "HEAD" : "GET"

        do {
            var (data, response) = try await session.data(for: request)

            // Some servers reject HEAD; retry once as GET before giving up.
            if let http = response as? HTTPURLResponse,
               http.statusCode == 405, request.httpMethod == "HEAD" {
                request.httpMethod = "GET"
                (data, response) = try await session.data(for: request)
            }

            guard let http = response as? HTTPURLResponse else {
                return SearchResult(site: site, username: username,
                                    status: .error("No response"), profileURL: nil)
            }

            let status = evaluate(site: site, http: http, body: data)
            return SearchResult(site: site, username: username,
                                status: status,
                                profileURL: status == .found ? profileURL : nil)
        } catch let error as URLError where error.code == .timedOut {
            return SearchResult(site: site, username: username,
                                status: .error("Timed out"), profileURL: nil)
        } catch {
            return SearchResult(site: site, username: username,
                                status: .error(error.localizedDescription), profileURL: nil)
        }
    }

    private func evaluate(site: SiteTarget, http: HTTPURLResponse, body: Data) -> SearchResult.Status {
        switch site.detection {
        case .statusCode:
            guard (200..<300).contains(http.statusCode) else { return .notFound }
            // If the server redirected us to its homepage the final URL path will
            // be "/" — treat that as not found (false-positive suppression).
            if let finalPath = http.url?.path, finalPath == "/" || finalPath.isEmpty {
                return .notFound
            }
            return .found
        case .message:
            guard let marker = site.errorMessage else {
                return (200..<300).contains(http.statusCode) ? .found : .notFound
            }
            let text = String(decoding: body, as: UTF8.self)
            return text.contains(marker) ? .notFound : .found
        }
    }
}
