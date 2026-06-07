import SwiftUI

// MARK: - ViewModel

@MainActor
final class FaceSearchViewModel: ObservableObject {
    @Published var session: FaceSession?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showSourcePicker = false
    @Published var showCamera = false
    @Published var showPhotoPicker = false
    @Published var engineFilter: FaceEngine? = nil
    @Published var detectedFaces: [DetectedFace] = []
    @Published var showFaceSelector = false
    @Published var selectedFace: DetectedFace? = nil
    @Published var originalImage: UIImage? = nil
    @Published var completedEngines: Set<FaceEngine> = []

    private let google = FaceGoogleLensService()
    private let yandex = FaceYandexService()
    private let pimEyes = FacePimEyesService()
    private let search4faces = FaceSearch4FacesService()

    func handleImage(_ image: UIImage) {
        showCamera = false; showPhotoPicker = false
        isProcessing = true; errorMessage = nil
        Task {
            do {
                let faces = try await FaceImageProcessor.detectAllFaces(from: image)
                if faces.isEmpty {
                    errorMessage = "No face detected in the selected photo."
                    isProcessing = false
                } else if faces.count == 1 {
                    await searchWithFace(faces[0])
                } else {
                    originalImage = image; detectedFaces = faces
                    showFaceSelector = true; isProcessing = false
                }
            } catch {
                errorMessage = error.localizedDescription; isProcessing = false
            }
        }
    }

    func searchWithFace(_ face: DetectedFace) async {
        isProcessing = true; selectedFace = face
        showFaceSelector = false; completedEngines = []
        do {
            let data = try FaceImageProcessor.compressToMaxSize(face.croppedImage)
            var s = FaceSession(faceImageData: data)
            session = s
            await withTaskGroup(of: (FaceEngine, [FaceSearchResult]).self) { group in
                group.addTask { (.googleLens,   (try? await self.google.search(imageData: data)) ?? []) }
                group.addTask { (.yandex,       (try? await self.yandex.search(imageData: data)) ?? []) }
                group.addTask { (.pimEyes,      (try? await self.pimEyes.search(imageData: data)) ?? []) }
                group.addTask { (.search4faces, (try? await self.search4faces.search(imageData: data)) ?? []) }
                for await (engine, results) in group {
                    s.results.append(contentsOf: results)
                    session = s
                    completedEngines.insert(engine)
                }
            }
            s.status = .completed; session = s
        } catch { errorMessage = error.localizedDescription }
        isProcessing = false
    }

    var displayedResults: [FaceSearchResult] {
        guard let s = session else { return [] }
        let deduped = s.deduplicatedResults
        guard let filter = engineFilter else { return deduped }
        return deduped.filter { $0.sourceEngine == filter }
    }
}

// MARK: - Main View

struct FaceSearchView: View {
    @StateObject private var vm = FaceSearchViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog("Choose Image Source", isPresented: $vm.showSourcePicker, titleVisibility: .visible) {
                Button("Camera") { vm.showCamera = true }
                Button("Photo Library") { vm.showPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $vm.showCamera) {
                FaceCameraPickerView(sourceType: .camera, onImage: vm.handleImage, onCancel: { vm.showCamera = false }).ignoresSafeArea()
            }
            .sheet(isPresented: $vm.showPhotoPicker) {
                FaceCameraPickerView(sourceType: .photoLibrary, onImage: vm.handleImage, onCancel: { vm.showPhotoPicker = false }).ignoresSafeArea()
            }
            .sheet(isPresented: $vm.showFaceSelector) {
                if let orig = vm.originalImage {
                    FaceMultiSelectView(originalImage: orig, faces: vm.detectedFaces,
                        onSelect: { face in Task { await vm.searchWithFace(face) } },
                        onCancel: { vm.showFaceSelector = false; vm.isProcessing = false })
                    .interactiveDismissDisabled()
                }
            }
            .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
                Button("OK") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
        }
        .preferredColorScheme(.dark)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Text("sherlock")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(-0.5)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { vm.showSourcePicker = true } label: {
                if vm.isProcessing && vm.session == nil {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                }
            }
            .disabled(vm.isProcessing)
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isProcessing, let face = vm.selectedFace {
            FaceScanAnimationView(
                faceImage: face.croppedImage,
                completedEngines: vm.completedEngines,
                totalEngines: FaceEngine.allCases.count
            )
        } else if let session = vm.session {
            resultsView(session: session)
        } else {
            emptyState
        }
    }

    // MARK: - Empty state (Sherlock-style)

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06)).frame(width: 110, height: 110)
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 1).frame(width: 140, height: 140)
                    Image(systemName: "person.crop.circle.badge.magnifyingglass")
                        .font(.system(size: 48)).foregroundStyle(.white)
                }
                VStack(spacing: 8) {
                    Text("find anyone's\nsocial media")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    Text("from just a face photo")
                        .font(.system(.subheadline))
                        .foregroundStyle(.gray)
                }
            }
            Spacer()
            VStack(spacing: 12) {
                featurePill(icon: "globe", text: "4 search engines")
                featurePill(icon: "person.2.fill", text: "Social profile matching")
                featurePill(icon: "eye.fill", text: "Biometric analysis")
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
            Button { vm.showSourcePicker = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                    Text("SCAN FACE")
                        .font(.system(.headline, design: .monospaced)).fontWeight(.bold)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24).padding(.bottom, 40)
        }
    }

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.caption).foregroundStyle(.gray)
            Text(text).font(.subheadline).foregroundStyle(.gray)
            Spacer()
        }
    }

    // MARK: - Results view (Sherlock-style)

    private func resultsView(session: FaceSession) -> some View {
        VStack(spacing: 0) {
            resultHeader(session: session)
            filterBar
            if vm.displayedResults.isEmpty {
                Spacer()
                if session.status == .completed {
                    noBrowserFallback
                } else {
                    ProgressView().tint(.white)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.displayedResults) { result in
                            FaceResultCard(result: result)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
        }
    }

    private func resultHeader(session: FaceSession) -> some View {
        HStack(spacing: 14) {
            if let img = UIImage(data: session.faceImageData) {
                ZStack {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 52, height: 52).clipShape(Circle())
                    Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5).frame(width: 52, height: 52)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(vm.displayedResults.count)")
                        .font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                    Text("match\(vm.displayedResults.count == 1 ? "" : "es")")
                        .font(.headline).foregroundStyle(.gray)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(session.status == .searching ? Color.yellow : Color.green)
                        .frame(width: 6, height: 6)
                    Text(session.status == .searching ? "Scanning platforms…" : "PLATFORM SEARCH COMPLETE")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(session.status == .searching ? .yellow : .green)
                }
            }
            Spacer()
            Button { vm.showSourcePicker = true } label: {
                Text("New").font(.caption).fontWeight(.semibold)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white.opacity(0.1)).clipShape(Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color(white: 0.07))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", isSelected: vm.engineFilter == nil) { vm.engineFilter = nil }
                ForEach(FaceEngine.allCases) { engine in
                    filterChip(title: engine.rawValue, isSelected: vm.engineFilter == engine) {
                        vm.engineFilter = (vm.engineFilter == engine) ? nil : engine
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Color(white: 0.05))
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .monospaced)).fontWeight(.semibold)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(isSelected ? Color.white : Color.white.opacity(0.08))
                .foregroundStyle(isSelected ? .black : .gray)
                .clipShape(Capsule())
        }
    }

    private var noBrowserFallback: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield").font(.largeTitle).foregroundStyle(.gray)
                Text("No results scraped").font(.headline).foregroundStyle(.white)
                Text("Search engines blocked automated access.\nOpen them in your browser to see results.")
                    .font(.caption).foregroundStyle(.gray).multilineTextAlignment(.center)
            }
            VStack(spacing: 10) {
                browserLink("Google Lens", url: "https://lens.google.com", color: .blue)
                browserLink("Yandex Images", url: "https://yandex.com/images", color: .orange)
                browserLink("PimEyes", url: "https://pimeyes.com", color: .purple)
                browserLink("Search4Faces", url: "https://search4faces.com", color: .green)
            }
            .padding(.horizontal, 32)
        }
    }

    private func browserLink(_ title: String, url: String, color: Color) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Circle().fill(color.opacity(0.2)).frame(width: 8, height: 8)
                Text(title).font(.subheadline).foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.up.right.circle").foregroundStyle(color)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Camera picker

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
