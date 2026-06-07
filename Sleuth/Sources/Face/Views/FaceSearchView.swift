import SwiftUI

@MainActor
final class FaceSearchViewModel: ObservableObject {
    @Published var session: FaceSession?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showSourcePicker = false
    @Published var showCamera = false
    @Published var showPhotoPicker = false
    @Published var engineFilter: FaceEngine? = nil

    private let google = FaceGoogleLensService()
    private let yandex = FaceYandexService()
    private let pimEyes = FacePimEyesService()

    func handleImage(_ image: UIImage) {
        showCamera = false; showPhotoPicker = false
        isProcessing = true; errorMessage = nil
        Task {
            do {
                let cropped = try await FaceImageProcessor.detectAndCropFace(from: image)
                let data = try FaceImageProcessor.compressToMaxSize(cropped)
                var s = FaceSession(faceImageData: data)
                session = s
                await withTaskGroup(of: [FaceSearchResult].self) { group in
                    group.addTask { (try? await self.google.search(imageData: data)) ?? [] }
                    group.addTask { (try? await self.yandex.search(imageData: data)) ?? [] }
                    group.addTask { (try? await self.pimEyes.search(imageData: data)) ?? [] }
                    for await results in group {
                        s.results.append(contentsOf: results)
                        session = s
                    }
                }
                s.status = .completed
                session = s
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }

    var displayedResults: [FaceSearchResult] {
        guard let s = session else { return [] }
        let deduped = s.deduplicatedResults
        guard let filter = engineFilter else { return deduped }
        return deduped.filter { $0.sourceEngine == filter }
    }
}

struct FaceSearchView: View {
    @StateObject private var vm = FaceSearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let session = vm.session {
                    headerBar(session: session)
                    filterBar
                    resultsList
                } else {
                    emptyState
                }
            }
            .navigationTitle("Face Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    scanButton
                }
            }
            .confirmationDialog("Choose Image Source", isPresented: $vm.showSourcePicker, titleVisibility: .visible) {
                Button("Camera") { vm.showCamera = true }
                Button("Photo Library") { vm.showPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $vm.showCamera) {
                FaceCameraPickerView(sourceType: .camera, onImage: vm.handleImage, onCancel: { vm.showCamera = false })
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $vm.showPhotoPicker) {
                FaceCameraPickerView(sourceType: .photoLibrary, onImage: vm.handleImage, onCancel: { vm.showPhotoPicker = false })
                    .ignoresSafeArea()
            }
            .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
                Button("OK") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
        }
    }

    private var scanButton: some View {
        Button {
            vm.showSourcePicker = true
        } label: {
            if vm.isProcessing {
                ProgressView().tint(.accentColor)
            } else {
                Image(systemName: "camera.viewfinder")
            }
        }
        .disabled(vm.isProcessing)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Search by Face",
            systemImage: "face.smiling",
            description: Text("Tap the camera icon to take or select a photo. FaceHunter will detect the face and search Google Lens, Yandex, and PimEyes.")
        )
    }

    private func headerBar(session: FaceSession) -> some View {
        HStack(spacing: 14) {
            if let img = UIImage(data: session.faceImageData) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(vm.displayedResults.count) result\(vm.displayedResults.count == 1 ? "" : "s")")
                    .font(.headline)
                HStack(spacing: 6) {
                    if session.status == .searching {
                        ProgressView().scaleEffect(0.7)
                        Text("Scanning…").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                        Text("Complete").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button { vm.showSourcePicker = true } label: {
                Text("New Scan").font(.caption).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.15)).clipShape(Capsule())
            }
        }
        .padding()
        .background(.bar)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "All", isSelected: vm.engineFilter == nil) { vm.engineFilter = nil }
                ForEach(FaceEngine.allCases) { engine in
                    FilterPill(title: engine.rawValue, isSelected: vm.engineFilter == engine) {
                        vm.engineFilter = (vm.engineFilter == engine) ? nil : engine
                    }
                }
            }
            .padding(.horizontal).padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        if vm.displayedResults.isEmpty {
            ContentUnavailableView(
                vm.session?.status == .searching ? "Searching…" : "No results found",
                systemImage: vm.session?.status == .searching ? "magnifyingglass" : "xmark.circle"
            )
        } else {
            List(vm.displayedResults) { result in
                FaceResultRow(result: result)
            }
            .listStyle(.plain)
        }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.caption).fontWeight(.semibold)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .secondary)
                .clipShape(Capsule())
        }
    }
}

struct FaceResultRow: View {
    let result: FaceSearchResult
    var body: some View {
        Button { UIApplication.shared.open(result.url) } label: {
            HStack(spacing: 12) {
                Image(systemName: result.platform.sfSymbol)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.platform.displayName).font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                    Text(result.url.absoluteString).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    FaceConfidenceBar(confidence: result.confidence)
                    Text(result.sourceEngine.rawValue).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct FaceConfidenceBar: View {
    let confidence: Double
    private var color: Color { confidence >= 0.7 ? .green : confidence >= 0.4 ? .yellow : .red }
    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(color).frame(width: geo.size.width * confidence)
                }
            }
            .frame(height: 4)
            Text("\(Int(confidence * 100))%").font(.caption2).foregroundStyle(color).frame(width: 32, alignment: .trailing)
        }
    }
}

struct FaceCameraPickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = sourceType; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: FaceCameraPickerView
        init(_ p: FaceCameraPickerView) { parent = p }
        func imagePickerController(_ p: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
        }
        func imagePickerControllerDidCancel(_ p: UIImagePickerController) { parent.onCancel() }
    }
}
