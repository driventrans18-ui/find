import SwiftUI

struct ResultRow: View {
    let result: SearchResult

    var body: some View {
        Button {
            UIApplication.shared.open(result.url)
        } label: {
            HStack(spacing: 12) {
                platformIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.platform.displayName)
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(result.url.absoluteString)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                    ConfidenceBar(confidence: result.confidence)
                    engineBadge
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, 8)
        }
    }

    private var platformIcon: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.18))
                .frame(width: Constants.UI.iconSize, height: Constants.UI.iconSize)
            Image(systemName: result.platform.sfSymbol)
                .font(.system(size: 14))
                .foregroundStyle(.white)
        }
    }

    private var engineBadge: some View {
        Text(result.sourceEngine.displayName)
            .font(.system(.caption2, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(white: 0.2))
            .foregroundStyle(.gray)
            .clipShape(Capsule())
    }
}

struct ConfidenceBar: View {
    let confidence: Double

    private var color: Color {
        if confidence >= 0.7 { return .green }
        if confidence >= 0.4 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * confidence)
                }
            }
            .frame(height: 4)
            Text("\(Int(confidence * 100))%")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
