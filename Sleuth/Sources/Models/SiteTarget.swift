import Foundation

/// How a site signals that an account does NOT exist.
enum DetectionMethod: String, Codable {
    /// Account is present when the HTTP status is 2xx; absent on 404/4xx.
    case statusCode = "status_code"
    /// Account is absent when `errorMessage` appears in the response body.
    case message
}

/// A single site we can look a username up on.
///
/// `urlTemplate` is the public, human-visitable profile URL with `{}` as the
/// username placeholder, e.g. `https://github.com/{}`. `probeTemplate` is the
/// URL we actually request to detect existence — usually the same, but some
/// sites expose a lighter-weight endpoint.
struct SiteTarget: Codable, Identifiable, Hashable {
    var id: String { name }

    let name: String
    let category: String
    let urlTemplate: String
    let probeTemplate: String?
    let detection: DetectionMethod
    /// Required when `detection == .message`.
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case name, category
        case urlTemplate = "url"
        case probeTemplate = "probe_url"
        case detection
        case errorMessage = "error_message"
    }

    /// Validate a username against this site's allowed characters.
    /// Most networks reject spaces; we keep this permissive but block the
    /// obviously invalid cases so we don't fire pointless requests.
    func isPlausible(username: String) -> Bool {
        guard !username.isEmpty else { return false }
        return !username.contains(where: { $0.isWhitespace })
    }

    func profileURL(for username: String) -> URL? {
        URL(string: urlTemplate.replacingOccurrences(of: "{}", with: encoded(username)))
    }

    func probeURL(for username: String) -> URL? {
        let template = probeTemplate ?? urlTemplate
        return URL(string: template.replacingOccurrences(of: "{}", with: encoded(username)))
    }

    private func encoded(_ username: String) -> String {
        username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
    }
}
