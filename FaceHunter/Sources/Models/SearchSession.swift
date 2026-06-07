import Foundation

struct SearchSession: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let faceImageData: Data
    var results: [SearchResult]
    var status: SessionStatus

    init(id: UUID = UUID(), createdAt: Date = Date(), faceImageData: Data) {
        self.id = id
        self.createdAt = createdAt
        self.faceImageData = faceImageData
        self.results = []
        self.status = .searching
    }

    enum SessionStatus: String, Codable {
        case searching
        case completed
        case failed
    }

    var deduplicatedResults: [SearchResult] {
        var seen = Set<String>()
        var unique: [SearchResult] = []
        let sorted = results.sorted { $0.confidence > $1.confidence }
        for result in sorted {
            let key = result.url.absoluteString
            if seen.insert(key).inserted {
                unique.append(result)
            }
        }
        return unique
    }

    func results(for engine: SearchEngine) -> [SearchResult] {
        deduplicatedResults.filter { $0.sourceEngine == engine }
    }
}
