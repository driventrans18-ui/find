import SwiftUI

struct SearchView: View {
    @ObservedObject var vm: SearchViewModel
    let session: SearchSession

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            searchBar
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: vm.selectedFilter == nil) {
                    vm.selectedFilter = nil
                }
                ForEach(SearchEngine.allCases) { engine in
                    let count = session.results(for: engine).count
                    FilterChip(
                        title: "\(engine.displayName) (\(count))",
                        isSelected: vm.selectedFilter == engine
                    ) {
                        vm.selectedFilter = (vm.selectedFilter == engine) ? nil : engine
                    }
                }
            }
            .padding(.horizontal, Constants.UI.padding)
            .padding(.vertical, 8)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray)
            TextField("Filter results…", text: $vm.searchText)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(10)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, Constants.UI.padding)
        .padding(.bottom, 8)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.red : Color(white: 0.15))
                .foregroundStyle(isSelected ? .white : .gray)
                .clipShape(Capsule())
        }
    }
}
