import Foundation

final class FacePimEyesService {
    // PimEyes sits behind Cloudflare — the full browser engine is required.
    // We use WKWebView to load their site, inject JS to submit the upload form,
    // then scrape the rendered results page for social profile links.
    func search(imageData: Data) async throws -> [FaceSearchResult] {
        guard let pageURL = URL(string: "https://pimeyes.com/en") else { return [] }
        let html = (try? await submitImageFormWithBrowser(
            pageURL: pageURL,
            imageData: imageData,
            waitAfterSubmit: 8.0
        )) ?? ""
        guard !html.isEmpty else { return [] }
        return parsePimEyesHTML(html)
    }

    private func parsePimEyesHTML(_ html: String) -> [FaceSearchResult] {
        // PimEyes results page contains face match cards with site URLs and similarity scores.
        // Pattern: data-url="https://..." or href="https://..." near a similarity percentage.
        let urlPattern = try! NSRegularExpression(
            pattern: #"(?:data-url|href)=["'](https?://[^"']+)["']"#,
            options: .caseInsensitive
        )
        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)
        var results: [FaceSearchResult] = []
        var seen = Set<String>()

        urlPattern.matches(in: html, range: range).forEach { m in
            guard m.numberOfRanges > 1 else { return }
            let urlStr = ns.substring(with: m.range(at: 1))
            guard seen.insert(urlStr).inserted,
                  let url = URL(string: urlStr),
                  FaceURLExtractor.isSocial(url),
                  let norm = FaceURLExtractor.normalize(url) else { return }
            results.append(FaceSearchResult(
                url: norm,
                platform: FacePlatform.from(host: url.host ?? ""),
                sourceEngine: .pimEyes,
                confidence: 0.8
            ))
        }
        return results
    }
}

enum FacePimEyesError: LocalizedError {
    case uploadFailed, submitFailed
    var errorDescription: String? {
        switch self { case .uploadFailed: return "PimEyes upload failed."; case .submitFailed: return "PimEyes search failed." }
    }
}
