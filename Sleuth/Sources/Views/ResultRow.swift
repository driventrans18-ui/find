import SwiftUI

struct ResultRow: View {
    let result: SearchResult

    var body: some View {
        if let url = result.profileURL {
            Link(destination: url) { rowBody }
        } else {
            rowBody
        }
    }

    private var rowBody: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.site.name)
                    .font(.headline)
                Text(result.site.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .foregroundStyle(.tint)
        }
        .contentShape(Rectangle())
    }
}
