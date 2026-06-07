import Foundation

final class FacePimEyesService {
    func search(imageData: Data) async throws -> [FaceSearchResult] {
        guard let pageURL = URL(string: "https://pimeyes.com/en") else { return [] }
        let html = (try? await submitImageFormWithBrowser(
            pageURL: pageURL,
            imageData: imageData,
            waitAfterSubmit: 5.0
        )) ?? ""
        guard !html.isEmpty else { return [] }
        return parsePimEyesHTML(html)
    }

    private func parsePimEyesHTML(_ html: String) -> [FaceSearchResult] {
        let ns = html as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        var results: [FaceSearchResult] = []
        var seen = Set<String>()

        // Collect all img srcs (face crop thumbnails from CDN)
        let imgPattern = try! NSRegularExpression(
            pattern: #"<img[^>]+src=["'](https?://[^"']+)["'][^>]*>"#,
            options: .caseInsensitive
        )
        struct Pos { let loc: Int; let value: String }
        var imgEntries: [Pos] = []
        imgPattern.matches(in: html, range: fullRange).forEach { m in
            guard m.numberOfRanges > 1 else { return }
            let src = ns.substring(with: m.range(at: 1))
            let low = src.lowercased()
            guard low.hasSuffix(".jpg") || low.hasSuffix(".jpeg") ||
                  low.hasSuffix(".png") || low.hasSuffix(".webp") ||
                  low.contains("cdn") || low.contains("thumb") || low.contains("face") else { return }
            imgEntries.append(Pos(loc: m.range.location, value: src))
        }

        // Collect all external source URLs (data-url, href, data-source)
        let urlPattern = try! NSRegularExpression(
            pattern: #"(?:data-url|data-source|href)=["'](https?://(?!pimeyes\.com)[^"']{10,})["']"#,
            options: .caseInsensitive
        )
        urlPattern.matches(in: html, range: fullRange).forEach { m in
            guard m.numberOfRanges > 1 else { return }
            let urlStr = ns.substring(with: m.range(at: 1))
            guard let url = URL(string: urlStr), seen.insert(urlStr).inserted else { return }

            // Confidence from nearby "92%" similarity text
            let searchStart = max(0, m.range.location - 600)
            let searchLen   = min(1200, ns.length - searchStart)
            let nearby = ns.substring(with: NSRange(location: searchStart, length: searchLen))
            let confidence: Double
            if let r = nearby.range(of: #"(\d{2,3})%"#, options: .regularExpression),
               let val = Double(nearby[r].dropLast()) {
                confidence = min(val / 100.0, 1.0)
            } else {
                confidence = 0.80
            }

            // Nearest face thumbnail within 2000 chars
            let linkLoc = m.range.location
            let thumbURL: URL? = imgEntries
                .filter { abs($0.loc - linkLoc) < 2000 }
                .min(by: { abs($0.loc - linkLoc) < abs($1.loc - linkLoc) })
                .flatMap { URL(string: $0.value) }

            results.append(FaceSearchResult(
                url: url,
                platform: FacePlatform.from(host: url.host ?? ""),
                sourceEngine: .pimEyes,
                confidence: confidence,
                thumbnailURL: thumbURL
            ))
        }
        return results
    }
}

enum FacePimEyesError: LocalizedError {
    case uploadFailed, submitFailed
    var errorDescription: String? {
        switch self {
        case .uploadFailed: return "PimEyes upload failed."
        case .submitFailed: return "PimEyes search failed."
        }
    }
}
