import Foundation

actor SessionStore {
    static let shared = SessionStore()

    private var sessions: [SearchSession] = []
    private let fileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = docs.appendingPathComponent(Constants.Storage.sessionsFileName)
        sessions = (try? load()) ?? []
    }

    func allSessions() -> [SearchSession] {
        sessions.sorted { $0.createdAt > $1.createdAt }
    }

    func save(session: SearchSession) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        } else {
            sessions.insert(session, at: 0)
        }
        try? persist()
    }

    func delete(sessionId: UUID) {
        sessions.removeAll { $0.id == sessionId }
        try? persist()
    }

    private func load() throws -> [SearchSession] {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([SearchSession].self, from: data)
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(sessions)
        try data.write(to: fileURL, options: .atomic)
    }
}
