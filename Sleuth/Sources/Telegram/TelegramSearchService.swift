import Foundation

final class TelegramSearchService {
    // Searches tgstat.com for channels/groups matching the keyword (English results).
    // Falls back to tgstat.ru if the first request fails or returns no results.
    func search(query: String) async throws -> [TelegramSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urls = [
            "https://tgstat.com/en/search?q=\(encoded)&type=channel&lang=en",
            "https://tgstat.ru/en/search?q=\(encoded)&type=channel&lang=en",
        ]
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            if let results = try? await fetchResults(from: url), !results.isEmpty {
                return results
            }
        }
        return []
    }

    private func fetchResults(from url: URL) async throws -> [TelegramSearchResult] {
        let html = try await fetchHTMLWithBrowser(url: url, waitAfterLoad: 3.0)
        return parse(html: html, baseURL: url)
    }

    // MARK: - HTML Parser

    private func parse(html: String, baseURL: URL) -> [TelegramSearchResult] {
        let ns = html as NSString
        var results: [TelegramSearchResult] = []

        // TGStat search result cards pattern (updated for current markup):
        //   <div class="peer-item ...">
        //     <a href="/channel/@handle" ...>
        //       <img src="...avatar...">
        //       <div class="peer-title">Title</div>
        //       <div class="peer-username">@handle</div>
        //       <div class="counter-item">12.4K subscribers</div>
        //       <div class="peer-description">...</div>

        // Extract full peer-item blocks first, then parse each one
        let blockPattern = try! NSRegularExpression(
            pattern: #"<(?:div|a)[^>]+class="[^"]*peer-item[^"]*"[^>]*>[\s\S]*?(?=<(?:div|a)[^>]+class="[^"]*peer-item|$)"#,
            options: [.caseInsensitive]
        )
        let fullRange = NSRange(location: 0, length: ns.length)
        let blocks = blockPattern.matches(in: html, range: fullRange).map { ns.substring(with: $0.range) }

        if !blocks.isEmpty {
            for block in blocks {
                if let r = parseBlock(block, baseURL: baseURL) { results.append(r) }
            }
            return results
        }

        // Fallback: simpler pattern — find every tgstat channel link with subscriber count
        return parseFallback(html: html, baseURL: baseURL)
    }

    private func parseBlock(_ block: String, baseURL: URL) -> TelegramSearchResult? {
        let ns = block as NSString

        // href for the channel page on tgstat
        let hrefMatch = firstMatch(in: block, pattern: #"href="(/(?:channel|group|bot)/@?[^"]+)""#, group: 1)
        guard let href = hrefMatch else { return nil }

        let tgstatURL: URL
        if let u = URL(string: href, relativeTo: URL(string: "https://tgstat.com"))?.absoluteURL {
            tgstatURL = u
        } else { return nil }

        // Extract @username from the href path
        let username = extractUsername(from: href)

        // Title
        let title = firstMatch(in: block, pattern: #"class="[^"]*peer-title[^"]*"[^>]*>\s*([^<]+)"#, group: 1)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (username.map { "@\($0)" } ?? "Unknown")

        // Description
        let description = firstMatch(in: block, pattern: #"class="[^"]*peer-description[^"]*"[^>]*>\s*([^<]{3,})"#, group: 1)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        // Subscriber / member count
        let subCount = firstMatch(in: block, pattern: #"([\d\s.,]+[KkMm]?)\s*(?:subscribers?|members?|участник)"#, group: 1)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        // Avatar img
        let avatarSrc = firstMatch(in: block, pattern: #"<img[^>]+src="([^"]+)"[^>]*>"#, group: 1)
        let avatarURL = avatarSrc.flatMap { URL(string: $0) }

        // Type from href prefix
        let type: TelegramSearchResult.ChannelType
        if href.contains("/group/") { type = .group }
        else if href.contains("/bot/") { type = .bot }
        else { type = .channel }

        // Telegram deep link
        let telegramURL = username.map { URL(string: "https://t.me/\($0)") } ?? nil

        return TelegramSearchResult(
            title: title,
            username: username,
            description: description,
            subscriberCount: subCount,
            type: type,
            avatarURL: avatarURL,
            tgstatURL: tgstatURL,
            telegramURL: telegramURL
        )
    }

    // Fallback parser when block regex doesn't match (layout variations)
    private func parseFallback(html: String, baseURL: URL) -> [TelegramSearchResult] {
        var results: [TelegramSearchResult] = []
        var seen = Set<String>()

        // Find all tgstat channel/group links
        let linkPattern = try! NSRegularExpression(
            pattern: #"href="((?:https?://tgstat\.(?:com|ru))?/(?:channel|group|bot)/@?([A-Za-z0-9_]{3,}))""#,
            options: .caseInsensitive
        )
        let ns = html as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        for m in linkPattern.matches(in: html, range: fullRange) {
            let href = ns.substring(with: m.range(at: 1))
            let user = m.numberOfRanges > 2 ? ns.substring(with: m.range(at: 2)) : nil
            guard let user, seen.insert(user).inserted else { continue }

            let tgstatBase = baseURL.absoluteString.contains("tgstat.ru") ? "https://tgstat.ru" : "https://tgstat.com"
            guard let tgstatURL = URL(string: href.hasPrefix("http") ? href : "\(tgstatBase)\(href)") else { continue }

            let type: TelegramSearchResult.ChannelType = href.contains("/group/") ? .group : .channel
            let telegramURL = URL(string: "https://t.me/\(user)")

            results.append(TelegramSearchResult(
                title: "@\(user)",
                username: user,
                description: "",
                subscriberCount: "",
                type: type,
                avatarURL: nil,
                tgstatURL: tgstatURL,
                telegramURL: telegramURL
            ))
        }
        return results
    }

    // MARK: - Helpers

    private func extractUsername(from href: String) -> String? {
        // /channel/@username  or  /channel/username
        let parts = href.split(separator: "/")
        return parts.last.map { s in
            let str = String(s)
            return str.hasPrefix("@") ? String(str.dropFirst()) : str
        }
    }

    private func firstMatch(in string: String, pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let m = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              m.numberOfRanges > group else { return nil }
        let range = m.range(at: group)
        guard range.location != NSNotFound,
              let r = Range(range, in: string) else { return nil }
        return String(string[r])
    }
}
