import Foundation

struct FaceSession: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let faceImageData: Data
    var results: [FaceSearchResult]
    var status: FaceSessionStatus

    init(id: UUID = UUID(), createdAt: Date = Date(), faceImageData: Data) {
        self.id = id
        self.createdAt = createdAt
        self.faceImageData = faceImageData
        self.results = []
        self.status = .searching
    }

    enum FaceSessionStatus: String, Codable { case searching, completed, failed }

    var deduplicatedResults: [FaceSearchResult] {
        var seen = Set<String>()
        return results
            .sorted { $0.confidence > $1.confidence }
            .filter { seen.insert($0.url.absoluteString).inserted }
    }
}
