import SwiftUI
import UIKit

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var showingSourcePicker = false
    @Published var showingCamera = false
    @Published var showingPhotoPicker = false
    @Published var activeSession: SearchSession?
    @Published var recentSessions: [SearchSession] = []
    @Published var errorMessage: String?
    @Published var isProcessing = false

    private let deps: AppDependencies

    init(deps: AppDependencies) {
        self.deps = deps
    }

    func loadSessions() async {
        recentSessions = await deps.sessionStore.allSessions()
    }

    func handleImage(_ image: UIImage) {
        showingCamera = false
        showingPhotoPicker = false
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let cropped = try await ImageProcessor.detectAndCropFace(from: image)
                let imageData = try ImageProcessor.compressToMaxSize(cropped)
                var session = SearchSession(faceImageData: imageData)
                await deps.sessionStore.save(session: session)
                activeSession = session

                // Stream results from all engines concurrently
                let stream = searchStream(session: &session, imageData: imageData)
                for await updatedSession in stream {
                    self.activeSession = updatedSession
                    await deps.sessionStore.save(session: updatedSession)
                    recentSessions = await deps.sessionStore.allSessions()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }

    private func searchStream(session: inout SearchSession, imageData: Data) -> AsyncStream<SearchSession> {
        let capturedSession = session
        let deps = self.deps

        return AsyncStream { continuation in
            Task {
                await withTaskGroup(of: [SearchResult].self) { group in
                    group.addTask { (try? await deps.googleLens.search(imageData: imageData)) ?? [] }
                    group.addTask { (try? await deps.yandex.search(imageData: imageData)) ?? [] }
                    group.addTask { (try? await deps.pimEyes.search(imageData: imageData)) ?? [] }

                    var running = capturedSession
                    for await results in group {
                        running.results.append(contentsOf: results)
                        continuation.yield(running)
                    }
                    running.status = .completed
                    continuation.yield(running)
                    continuation.finish()
                }
            }
        }
    }

    func deleteSession(_ session: SearchSession) async {
        await deps.sessionStore.delete(sessionId: session.id)
        recentSessions = await deps.sessionStore.allSessions()
    }
}
