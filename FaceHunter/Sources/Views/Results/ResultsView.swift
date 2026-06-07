import SwiftUI

struct ResultsView: View {
    @StateObject private var vm: ResultsViewModel
    private let deps: AppDependencies

    init(session: SearchSession, deps: AppDependencies) {
        _vm = StateObject(wrappedValue: ResultsViewModel(session: session))
        self.deps = deps
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                faceCropHeader
                SearchView(vm: vm.search, session: vm.session)
                resultsList
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    vm.prepareExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.red)
                }
            }
        }
        .sheet(isPresented: $vm.showingShareSheet) {
            ShareSheet(items: vm.shareItems)
        }
    }

    private var faceCropHeader: some View {
        HStack(spacing: 16) {
            FaceCropView(imageData: vm.session.faceImageData)
            VStack(alignment: .leading, spacing: 6) {
                Text(vm.session.createdAt, style: .date)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.gray)
                Text("\(vm.displayedResults.count) match\(vm.displayedResults.count == 1 ? "" : "es")")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                statusBadge
            }
            Spacer()
        }
        .padding(Constants.UI.padding)
        .background(Color(white: 0.08))
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            if vm.session.status == .searching {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.yellow)
            }
            Text(vm.session.status == .searching ? "SCANNING" : "COMPLETE")
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(vm.session.status == .searching ? .yellow : .green)
        }
    }

    private var resultsList: some View {
        Group {
            if vm.displayedResults.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: vm.session.status == .searching ? "magnifyingglass" : "xmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.gray)
                    Text(vm.session.status == .searching ? "Searching…" : "No results found")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                Spacer()
            } else {
                List {
                    ForEach(vm.displayedResults) { result in
                        ResultRow(result: result)
                            .listRowBackground(Color(white: 0.1))
                            .listRowSeparatorTint(Color(white: 0.2))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
