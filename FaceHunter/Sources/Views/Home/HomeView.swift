import SwiftUI

struct HomeView: View {
    @StateObject private var vm: HomeViewModel
    private let deps: AppDependencies

    init(deps: AppDependencies) {
        self.deps = deps
        _vm = StateObject(wrappedValue: HomeViewModel(deps: deps))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerSection
                    scanButton
                    recentSessionsList
                }
            }
            .navigationDestination(item: $vm.activeSession) { session in
                ResultsView(session: session, deps: deps)
            }
            .sheet(isPresented: $vm.showingCamera) {
                CameraView(sourceType: .camera, onImage: vm.handleImage, onCancel: { vm.showingCamera = false })
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $vm.showingPhotoPicker) {
                CameraView(sourceType: .photoLibrary, onImage: vm.handleImage, onCancel: { vm.showingPhotoPicker = false })
                    .ignoresSafeArea()
            }
            .confirmationDialog("Choose Image Source", isPresented: $vm.showingSourcePicker, titleVisibility: .visible) {
                Button("Camera") { vm.showingCamera = true }
                Button("Photo Library") { vm.showingPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
        .task { await vm.loadSessions() }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
                .padding(.top, 48)
            Text("FaceHunter")
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text("OSINT Reverse Face Search")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.gray)
        }
        .padding(.bottom, 36)
    }

    private var scanButton: some View {
        Button {
            vm.showingSourcePicker = true
        } label: {
            HStack(spacing: 12) {
                if vm.isProcessing {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                }
                Text(vm.isProcessing ? "SCANNING…" : "SCAN FACE")
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(vm.isProcessing ? Color.gray : Color.red)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
            .padding(.horizontal, Constants.UI.padding)
        }
        .disabled(vm.isProcessing)
    }

    private var recentSessionsList: some View {
        Group {
            if vm.recentSessions.isEmpty {
                Spacer()
                Text("No sessions yet")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.gray)
                Spacer()
            } else {
                List {
                    Section {
                        ForEach(vm.recentSessions) { session in
                            NavigationLink(value: session) {
                                SessionRow(session: session)
                            }
                            .listRowBackground(Color(white: 0.1))
                        }
                        .onDelete { offsets in
                            Task {
                                for idx in offsets {
                                    await vm.deleteSession(vm.recentSessions[idx])
                                }
                            }
                        }
                    } header: {
                        Text("RECENT SESSIONS")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct SessionRow: View {
    let session: SearchSession

    var body: some View {
        HStack(spacing: 12) {
            if let img = UIImage(data: session.faceImageData) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(session.createdAt, style: .date)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.white)
                Text("\(session.deduplicatedResults.count) results · \(session.status.rawValue.uppercased())")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(session.status == .completed ? .green : .yellow)
            }
            Spacer()
        }
    }
}
