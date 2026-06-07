import SwiftUI

// MARK: - ViewModel

@MainActor
final class FaceSearchViewModel: ObservableObject {
    @Published var faceImage: UIImage?
    @Published var faceData: Data?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showSourcePicker = false
    @Published var showCamera = false
    @Published var showPhotoPicker = false
    @Published var detectedFaces: [DetectedFace] = []
    @Published var showFaceSelector = false
    @Published var originalImage: UIImage? = nil
    // Which engine browser is open
    @Published var activeEngineURL: URL? = nil
    // Upload state per engine
    @Published var engineURLs: [FaceEngine: URL] = [:]
    @Published var engineErrors: [FaceEngine: String] = [:]
    @Published var uploadingEngines: Set<FaceEngine> = []

    let yandex = FaceYandexService()
    let google = FaceGoogleLensService()

    func handleImage(_ image: UIImage) {
        showCamera = false; showPhotoPicker = false
        isProcessing = true; errorMessage = nil
        Task {
            do {
                let normalized = FaceImageProcessor.normalizeOrientation(image)
                let faces = try await FaceImageProcessor.detectAllFaces(from: normalized)
                if faces.isEmpty {
                    errorMessage = "No face detected in the selected photo."
                    isProcessing = false
                } else if faces.count == 1 {
                    await selectFace(faces[0], normalized: normalized)
                } else {
                    originalImage = normalized; detectedFaces = faces
                    showFaceSelector = true; isProcessing = false
                }
            } catch {
                errorMessage = error.localizedDescription; isProcessing = false
            }
        }
    }

    func selectFace(_ face: DetectedFace, normalized: UIImage? = nil) async {
        showFaceSelector = false
        isProcessing = true
        do {
            let data = try FaceImageProcessor.compressToMaxSize(face.croppedImage)
            faceData = data
            faceImage = face.croppedImage
            engineURLs = [:]
            engineErrors = [:]
            uploadingEngines = [.yandex, .googleLens]
            isProcessing = false
            // Upload to Yandex and Google Lens in background; PimEyes/Search4Faces open directly
            async let yURL: URL? = yandex.uploadAndGetResultURL(imageData: data)
            async let gURL: URL? = google.uploadAndGetResultURL(imageData: data)
            let (y, g) = await (yURL, gURL)
            uploadingEngines = []
            if let u = y { engineURLs[.yandex] = u }
            else { engineErrors[.yandex] = "Upload failed" }
            if let u = g { engineURLs[.googleLens] = u }
            else { engineErrors[.googleLens] = "Upload failed" }
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }

    func reset() {
        faceImage = nil; faceData = nil
        engineURLs = [:]; engineErrors = [:]
        uploadingEngines = []
    }
}

// MARK: - Main View

struct FaceSearchView: View {
    @StateObject private var vm = FaceSearchViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if vm.isProcessing {
                    processingView
                } else if vm.faceImage != nil {
                    engineListView
                } else {
                    emptyState
                }
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
                    FaceMultiSelectView(
                        originalImage: orig,
                        faces: vm.detectedFaces,
                        onSelect: { face in Task { await vm.selectFace(face, normalized: orig) } },
                        onCancel: { vm.showFaceSelector = false; vm.isProcessing = false }
                    ).interactiveDismissDisabled()
                }
            }
            .sheet(item: $vm.activeEngineURL) { url in
                InAppBrowser(url: url)
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
                .foregroundStyle(.white).tracking(-0.5)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { vm.showSourcePicker = true } label: {
                if vm.isProcessing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                }
            }
            .disabled(vm.isProcessing)
        }
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white).scaleEffect(1.5)
            Text("Detecting face…")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Engine list (after face selected)

    private var engineListView: some View {
        VStack(spacing: 0) {
            // Face preview header
            if let img = vm.faceImage {
                HStack(spacing: 14) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 64, height: 64).clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Face ready")
                            .font(.headline).foregroundStyle(.white)
                        Text("Tap an engine to search")
                            .font(.caption).foregroundStyle(.gray)
                    }
                    Spacer()
                    Button { vm.reset() } label: {
                        Text("Clear")
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.white.opacity(0.1)).clipShape(Capsule())
                            .foregroundStyle(.white)
                    }
                }
                .padding(16)
                .background(Color(white: 0.07))
            }

            ScrollView {
                VStack(spacing: 12) {
                    engineRow(engine: .googleLens,
                              name: "Google Lens",
                              subtitle: "Finds visually similar faces across the web",
                              icon: "globe",
                              color: .blue)

                    engineRow(engine: .yandex,
                              name: "Yandex Images",
                              subtitle: "Reverse image search — great for Eastern Europe",
                              icon: "magnifyingglass.circle.fill",
                              color: .orange)

                    directEngineRow(name: "PimEyes",
                                    subtitle: "Face recognition search — upload manually",
                                    icon: "eye.fill",
                                    color: .purple,
                                    url: URL(string: "https://pimeyes.com/en")!)

                    directEngineRow(name: "Search4Faces",
                                    subtitle: "Find VK & OK.ru profiles by face",
                                    icon: "person.2.fill",
                                    color: .green,
                                    url: URL(string: "https://search4faces.com/en/")!)
                }
                .padding(16)
            }
        }
    }

    // Engine that auto-uploads and opens results
    private func engineRow(engine: FaceEngine, name: String, subtitle: String, icon: String, color: Color) -> some View {
        let isUploading = vm.uploadingEngines.contains(engine)
        let resultURL = vm.engineURLs[engine]
        let hasError = vm.engineErrors[engine] != nil

        return Button {
            if let url = resultURL {
                vm.activeEngineURL = url
            } else if !isUploading {
                // Retry upload
                guard let data = vm.faceData else { return }
                Task {
                    vm.uploadingEngines.insert(engine)
                    if engine == .yandex {
                        if let u = await vm.yandex.uploadAndGetResultURL(imageData: data) { vm.engineURLs[.yandex] = u }
                        else { vm.engineErrors[.yandex] = "Upload failed" }
                    } else {
                        if let u = await vm.google.uploadAndGetResultURL(imageData: data) { vm.engineURLs[.googleLens] = u }
                        else { vm.engineErrors[.googleLens] = "Upload failed" }
                    }
                    vm.uploadingEngines.remove(engine)
                }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.headline).foregroundStyle(.white)
                    Text(subtitle).font(.caption).foregroundStyle(.gray).lineLimit(2)
                }
                Spacer()
                if isUploading {
                    ProgressView().tint(.gray)
                } else if resultURL != nil {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .foregroundStyle(color).font(.title3)
                } else if hasError {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundStyle(.orange).font(.title3)
                } else {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundStyle(.gray).font(.title3)
                }
            }
            .padding(14)
            .background(Color(white: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                resultURL != nil ? color.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // Engine that opens directly (user uploads manually in the browser)
    private func directEngineRow(name: String, subtitle: String, icon: String, color: Color, url: URL) -> some View {
        Button { vm.activeEngineURL = url } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.headline).foregroundStyle(.white)
                    Text(subtitle).font(.caption).foregroundStyle(.gray).lineLimit(2)
                }
                Spacer()
                Image(systemName: "arrow.up.right.circle")
                    .foregroundStyle(color).font(.title3)
            }
            .padding(14)
            .background(Color(white: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

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
                        .foregroundStyle(.white).multilineTextAlignment(.center).lineSpacing(2)
                    Text("from just a face photo")
                        .font(.system(.subheadline)).foregroundStyle(.gray)
                }
            }
            Spacer()
            VStack(spacing: 12) {
                featurePill(icon: "globe", text: "Google Lens + Yandex auto-upload")
                featurePill(icon: "eye.fill", text: "PimEyes face recognition")
                featurePill(icon: "person.2.fill", text: "Search4Faces VK/OK.ru lookup")
            }
            .padding(.horizontal, 40).padding(.bottom, 32)
            Button { vm.showSourcePicker = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                    Text("SCAN FACE").font(.system(.headline, design: .monospaced)).fontWeight(.bold)
                }
                .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
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
