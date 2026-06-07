import Foundation

/// The outcome of probing a single site for a username.
struct SearchResult: Identifiable, Hashable {
    enum Status: Hashable {
        case found
        case notFound
        case error(String)
    }

    let id = UUID()
    let site: SiteTarget
    let username: String
    var status: Status
    /// The public profile URL to open when the account was found.
    var profileURL: URL?

    var isFound: Bool {
        if case .found = status { return true }
        return false
    }
}

/// A completed search the user can revisit from history.
struct SearchHistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let username: String
    let date: Date
    let foundCount: Int
    let totalCount: Int

    init(id: UUID = UUID(), username: String, date: Date = .now, foundCount: Int, totalCount: Int) {
        self.id = id
        self.username = username
        self.date = date
        self.foundCount = foundCount
        self.totalCount = totalCount
    }
}
