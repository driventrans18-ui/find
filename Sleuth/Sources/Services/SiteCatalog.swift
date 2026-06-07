import Foundation

/// Provides the current site list.
///
/// Sites are served from `SherlockCatalog.shared`, which may hold data fetched
/// from the remote Sherlock database or fall back to the bundled sites.json.
enum SiteCatalog {
    static var all: [SiteTarget] {
        // SherlockCatalog.shared.sites is populated by load() on app start.
        // Actor-isolated access is safe here because we only read the value
        // that was already set synchronously via SherlockCatalog.shared.load()
        // before the first UI frame renders.  After a refresh() completes the
        // search callers re-read this property, picking up the new list.
        SherlockCatalog.unsafeSites
    }

    static var categories: [String] {
        Array(Set(all.map(\.category))).sorted()
    }
}
