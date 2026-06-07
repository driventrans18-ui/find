import Foundation

/// Remote Sherlock project site database integration.
///
/// On first launch `load()` populates `sites` from the cached
/// Documents/sherlock_sites.json (if present) or from the bundled sites.json.
/// Calling `refresh()` fetches the latest data from GitHub in the background,
/// parses it, persists it, and updates `sites`.
actor SherlockCatalog {
    static let shared = SherlockCatalog()

    /// Non-isolated cache readable from synchronous callers (SiteCatalog.all).
    /// Pre-populated at static init time so sites are available before .task runs.
    nonisolated(unsafe) private(set) static var unsafeSites: [SiteTarget] = SherlockCatalog.eagerLoad()
    /// Whether the current data came from a successful Sherlock fetch.
    nonisolated(unsafe) private(set) static var unsafeLoadedFromSherlock: Bool = false

    // Runs synchronously at launch (before any UI frame) to populate unsafeSites
    // from the on-disk cache or bundled fallback.
    private static func eagerLoad() -> [SiteTarget] {
        if let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode([SiteTarget].self, from: data),
           !decoded.isEmpty {
            unsafeLoadedFromSherlock = true
            return decoded
        }
        guard let url = Bundle.main.url(forResource: "sites", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SiteTarget].self, from: data) else { return [] }
        return decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private(set) var sites: [SiteTarget] = [] {
        didSet {
            SherlockCatalog.unsafeSites = sites
        }
    }
    private(set) var loadedFromSherlock = false {
        didSet {
            SherlockCatalog.unsafeLoadedFromSherlock = loadedFromSherlock
        }
    }

    private static let remoteURL = URL(string:
        "https://raw.githubusercontent.com/sherlock-project/sherlock/main/sherlock/resources/data.json"
    )!

    private static var cacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sherlock_sites.json")
    }

    private init() {}

    // MARK: - Public API

    /// Load cached/bundled sites so the UI has data immediately.
    /// Call this before the first UI frame, e.g. in App.init().
    func load() {
        let cache = Self.cacheURL
        if FileManager.default.fileExists(atPath: cache.path),
           let data = try? Data(contentsOf: cache),
           let decoded = try? JSONDecoder().decode([SiteTarget].self, from: data) {
            sites = decoded
            loadedFromSherlock = true
            return
        }
        sites = loadBundled()
        loadedFromSherlock = false
    }

    /// Fetch latest Sherlock data.json from GitHub, parse and persist it.
    /// Silently keeps existing data on any failure.
    func refresh() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.remoteURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let parsed = try parseSherlock(data: data)
            guard !parsed.isEmpty else { return }
            let encoded = try JSONEncoder().encode(parsed)
            try encoded.write(to: Self.cacheURL, options: .atomic)
            sites = parsed
            loadedFromSherlock = true
        } catch {
            // Network or parse failure — keep whatever is already loaded
        }
    }

    // MARK: - Parsing

    private func parseSherlock(data: Data) throws -> [SiteTarget] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var result: [SiteTarget] = []
        result.reserveCapacity(root.count)

        for (siteName, info) in root {
            guard let urlTemplate = info["url"] as? String,
                  urlTemplate.contains("{}") else { continue }

            let probeTemplate = info["urlProbe"] as? String

            // Map errorType to DetectionMethod
            let errorTypeRaw = info["errorType"] as? String ?? "status_code"
            let detection: DetectionMethod
            switch errorTypeRaw {
            case "message":
                detection = .message
            default:
                // "status_code" and "response_url" both treated as statusCode
                detection = .statusCode
            }

            // errorMsg can be a String or [String]
            let errorMessage: String?
            if let msg = info["errorMsg"] as? String {
                errorMessage = msg
            } else if let msgs = info["errorMsg"] as? [String] {
                errorMessage = msgs.first
            } else {
                errorMessage = nil
            }

            // Derive category from tags
            let tags = info["tags"] as? [String] ?? []
            let category = categoryFromTags(tags)

            let regexCheck = info["regexCheck"] as? String

            let target = SiteTarget(
                name: siteName,
                category: category,
                urlTemplate: urlTemplate,
                probeTemplate: probeTemplate,
                detection: detection,
                errorMessage: errorMessage,
                regexCheck: regexCheck
            )
            result.append(target)
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func categoryFromTags(_ tags: [String]) -> String {
        let mapping: [String: String] = [
            "social": "Social",
            "gaming": "Gaming",
            "coding": "Coding",
            "photo": "Photo",
            "video": "Video",
            "music": "Music",
            "dating": "Dating",
            "blog": "Blog",
            "forum": "Forum",
            "news": "News",
            "adult": "Adult"
        ]
        for tag in tags {
            if let mapped = mapping[tag.lowercased()] {
                return mapped
            }
        }
        if let first = tags.first {
            return first.prefix(1).uppercased() + first.dropFirst()
        }
        return "Other"
    }

    private func loadBundled() -> [SiteTarget] {
        guard let url = Bundle.main.url(forResource: "sites", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SiteTarget].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
