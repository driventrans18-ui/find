import SwiftUI

struct FaceScanAnimationView: View {
    let faceImage: UIImage
    let completedEngines: Set<FaceEngine>
    let totalEngines: Int

    @State private var scanLineOffset: CGFloat = -120
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var dotCount = 1
    @State private var ringRotation: Double = 0

    private let ovalW: CGFloat = 190
    private let ovalH: CGFloat = 230

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                biometricCircle
                statusText
                engineRows
                Spacer()
            }
        }
        .onAppear { startAnimations() }
    }

    private var biometricCircle: some View {
        ZStack {
            ForEach([1.15, 1.3, 1.45], id: \.self) { scale in
                Ellipse()
                    .stroke(Color.cyan.opacity(glowOpacity / (scale * 1.8)), lineWidth: 1)
                    .frame(width: ovalW * scale, height: ovalH * scale)
                    .scaleEffect(pulseScale)
            }
            Ellipse()
                .stroke(
                    AngularGradient(colors: [.cyan, .clear, .cyan.opacity(0.4), .clear], center: .center),
                    lineWidth: 1.5
                )
                .frame(width: ovalW * 1.07, height: ovalH * 1.07)
                .rotationEffect(.degrees(ringRotation))
            Image(uiImage: faceImage)
                .resizable()
                .scaledToFill()
                .frame(width: ovalW, height: ovalH)
                .clipShape(Ellipse())
                .overlay(scanLine)
                .overlay(Ellipse().stroke(Color.cyan.opacity(0.6), lineWidth: 1.5))
            cornerBrackets
        }
        .frame(width: ovalW * 1.55, height: ovalH * 1.55)
    }

    private var scanLine: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, .cyan.opacity(0.9), .clear], startPoint: .top, endPoint: .bottom))
            .frame(height: 3)
            .offset(y: scanLineOffset)
            .clipShape(Ellipse().scale(1.0))
    }

    private var cornerBrackets: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, l: CGFloat = 16, lw: CGFloat = 2.5
            Group {
                Path { p in p.move(to: .init(x: 0, y: l)); p.addLine(to: .init(x: 0, y: 0)); p.addLine(to: .init(x: l, y: 0)) }.stroke(Color.cyan, lineWidth: lw)
                Path { p in p.move(to: .init(x: w-l, y: 0)); p.addLine(to: .init(x: w, y: 0)); p.addLine(to: .init(x: w, y: l)) }.stroke(Color.cyan, lineWidth: lw)
                Path { p in p.move(to: .init(x: 0, y: h-l)); p.addLine(to: .init(x: 0, y: h)); p.addLine(to: .init(x: l, y: h)) }.stroke(Color.cyan, lineWidth: lw)
                Path { p in p.move(to: .init(x: w-l, y: h)); p.addLine(to: .init(x: w, y: h)); p.addLine(to: .init(x: w, y: h-l)) }.stroke(Color.cyan, lineWidth: lw)
            }
        }
        .frame(width: ovalW, height: ovalH)
    }

    private var statusText: some View {
        VStack(spacing: 6) {
            Text("BIOMETRIC ANALYSIS")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(.cyan)
                .tracking(3)
            Text("Mapping biometric data" + String(repeating: ".", count: dotCount))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.55))
                .frame(height: 14)
        }
    }

    private var engineRows: some View {
        VStack(spacing: 10) {
            ForEach(FaceEngine.allCases) { engine in
                HStack(spacing: 10) {
                    if completedEngines.contains(engine) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.cyan).font(.caption)
                    } else {
                        ProgressView().scaleEffect(0.55).tint(.cyan).frame(width: 14, height: 14)
                    }
                    Text(engine.rawValue.uppercased())
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(completedEngines.contains(engine) ? .cyan : .cyan.opacity(0.35))
                        .tracking(1)
                    Spacer()
                    Text(completedEngines.contains(engine) ? "DONE" : "SCANNING")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(completedEngines.contains(engine) ? .cyan.opacity(0.5) : .cyan.opacity(0.25))
                }
                .padding(.horizontal, 44)
            }
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.06; glowOpacity = 0.85
        }
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: true)) {
            scanLineOffset = 120
        }
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            dotCount = dotCount % 3 + 1
        }
    }
}
