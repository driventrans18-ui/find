import SwiftUI

struct ResultRow: View {
    let result: SearchResult
    @State private var browserURL: URL? = nil

    var body: some View {
        Button {
            if let url = result.profileURL { browserURL = url }
        } label: { rowBody }
        .buttonStyle(.plain)
        .sheet(item: $browserURL) { url in
            InAppBrowser(url: url)
        }
    }

    private var rowBody: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.site.name)
                    .font(.headline)
                if let url = result.profileURL {
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(result.site.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .foregroundStyle(.tint)
        }
        .contentShape(Rectangle())
    }
}
