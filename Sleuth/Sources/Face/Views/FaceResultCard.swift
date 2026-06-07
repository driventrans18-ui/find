import SwiftUI

struct FaceResultCard: View {
    let result: FaceSearchResult

    var body: some View {
        Button { UIApplication.shared.open(result.url) } label: {
            HStack(spacing: 14) {
                thumbnail
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(result.platform.displayName)
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                        Spacer()
                        confidenceBadge
                    }
                    Text(result.url.host ?? result.url.absoluteString)
                        .font(.caption2).foregroundStyle(.gray).lineLimit(1)
                    engineBadge
                }
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.gray)
            }
            .padding(14)
            .background(Color(white: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbURL = result.thumbnailURL {
            AsyncImage(url: thumbURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                default:
                    platformIcon
                }
            }
        } else {
            platformIcon
        }
    }

    private var platformIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)).frame(width: 58, height: 58)
            Image(systemName: result.platform.sfSymbol).font(.system(size: 22)).foregroundStyle(.white.opacity(0.7))
        }
    }

    private var confidenceBadge: some View {
        let pct = Int(result.confidence * 100)
        let color: Color = result.confidence >= 0.7 ? .green : result.confidence >= 0.4 ? .yellow : .red
        return Text("\(pct)%")
            .font(.system(.caption2, design: .monospaced)).fontWeight(.bold).foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.15)).clipShape(Capsule())
    }

    private var engineBadge: some View {
        Text(result.sourceEngine.rawValue)
            .font(.system(.caption2, design: .monospaced)).foregroundStyle(.gray)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.white.opacity(0.06)).clipShape(Capsule())
    }
}
