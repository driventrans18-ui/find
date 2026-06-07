import SwiftUI

struct FaceResultCard: View {
    let result: FaceSearchResult
    @State private var browserURL: URL? = nil

    var body: some View {
        Button { browserURL = result.url } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Big face thumbnail when available
                if let thumbURL = result.thumbnailURL {
                    AsyncImage(url: thumbURL) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipped()
                        case .failure:
                            fallbackHeader
                        default:
                            ZStack {
                                Color(white: 0.13).frame(height: 180)
                                ProgressView().tint(.gray)
                            }
                        }
                    }
                    .clipShape(RoundedTopCorners(radius: 14))
                } else {
                    fallbackHeader
                }

                // Info row
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.platform.displayName)
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                        Text(result.url.host ?? result.url.absoluteString)
                            .font(.caption2).foregroundStyle(.gray).lineLimit(1)
                    }
                    Spacer()
                    confidenceBadge
                    Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                engineBadge
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
            .background(Color(white: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(item: $browserURL) { url in InAppBrowser(url: url) }
    }

    // Shown when no thumbnail — compact horizontal layout
    private var fallbackHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 52, height: 52)
                Image(systemName: result.platform.sfSymbol)
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.6))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(result.platform.displayName)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                Text(result.url.host ?? result.url.absoluteString)
                    .font(.caption2).foregroundStyle(.gray).lineLimit(1)
            }
            Spacer()
            confidenceBadge
            Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(.gray)
        }
        .padding(12)
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

// Rounds only the top two corners
private struct RoundedTopCorners: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
