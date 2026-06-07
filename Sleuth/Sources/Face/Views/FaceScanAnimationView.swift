import SwiftUI

struct FaceScanAnimationView: View {
    @Binding var completedEngines: Set<FaceEngine>
    let totalEngines: Int

    // Scan line animation (0 = top of oval, 1 = bottom)
    @State private var scanProgress: CGFloat = 0
    // Glow pulse (0...1)
    @State private var glowPulse: CGFloat = 0
    // Dot count cycling (1, 2, 3)
    @State private var dotCount: Int = 1

    private let ovalWidth: CGFloat = 220
    private let ovalHeight: CGFloat = 280

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Face oval with scan line
                ZStack {
                    // Glow backdrop
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [Color.red.opacity(0.15 * glowPulse), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: ovalWidth * 0.8
                            )
                        )
                        .frame(width: ovalWidth + 40, height: ovalHeight + 40)

                    // Main oval border with pulsing glow
                    Ellipse()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.red.opacity(0.4 + 0.6 * glowPulse),
                                    Color.orange.opacity(0.3 + 0.5 * glowPulse),
                                    Color.red.opacity(0.4 + 0.6 * glowPulse)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: ovalWidth, height: ovalHeight)
                        .shadow(color: Color.red.opacity(0.6 * glowPulse), radius: 10)

                    // Clip scan line to oval shape
                    scanLine
                        .clipShape(Ellipse().size(width: ovalWidth, height: ovalHeight).offset(x: 0, y: 0))
                        .frame(width: ovalWidth, height: ovalHeight)

                    // Corner bracket decorations
                    cornerBrackets
                        .frame(width: ovalWidth + 20, height: ovalHeight + 20)
                }

                // "SCANNING FACE" label
                Text("SCANNING FACE")
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.red)
                    .tracking(4)

                // Animated dots
                Text(String(repeating: ".", count: dotCount))
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.red.opacity(0.8))
                    .frame(width: 40, alignment: .leading)
                    .animation(.none, value: dotCount)

                // Engine status rows
                VStack(spacing: 12) {
                    ForEach(FaceEngine.allCases) { engine in
                        engineRow(engine)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Scan line

    private var scanLine: some View {
        GeometryReader { geo in
            let lineY = geo.size.height * scanProgress
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.red.opacity(0.3),
                            Color.red.opacity(0.85),
                            Color.red.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .shadow(color: Color.red.opacity(0.9), radius: 6, y: 0)
                .position(x: geo.size.width / 2, y: lineY)
        }
    }

    // MARK: - Corner brackets

    private var cornerBrackets: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let len: CGFloat = 18
            let thick: CGFloat = 2
            let col = Color.red.opacity(0.7)

            Group {
                // Top-left
                bracket(x: 0, y: 0, len: len, thick: thick, color: col, flipX: false, flipY: false)
                // Top-right
                bracket(x: w - len, y: 0, len: len, thick: thick, color: col, flipX: true, flipY: false)
                // Bottom-left
                bracket(x: 0, y: h - len, len: len, thick: thick, color: col, flipX: false, flipY: true)
                // Bottom-right
                bracket(x: w - len, y: h - len, len: len, thick: thick, color: col, flipX: true, flipY: true)
            }
        }
    }

    private func bracket(x: CGFloat, y: CGFloat, len: CGFloat, thick: CGFloat, color: Color, flipX: Bool, flipY: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            // Horizontal arm
            Rectangle()
                .fill(color)
                .frame(width: len, height: thick)
                .offset(x: x, y: flipY ? y + len - thick : y)

            // Vertical arm
            Rectangle()
                .fill(color)
                .frame(width: thick, height: len)
                .offset(x: flipX ? x + len - thick : x, y: y)
        }
    }

    // MARK: - Engine row

    private func engineRow(_ engine: FaceEngine) -> some View {
        let done = completedEngines.contains(engine)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(done ? Color.green : Color.red.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.green)
                } else {
                    // Spinning indicator
                    SpinnerArc()
                        .frame(width: 20, height: 20)
                }
            }

            Text(engine.rawValue)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(done ? Color.green : Color.white.opacity(0.7))
                .tracking(1)

            Spacer()

            Text(done ? "DONE" : "SCANNING")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(done ? Color.green.opacity(0.8) : Color.red.opacity(0.6))
                .tracking(1)
        }
    }

    // MARK: - Animation control

    private func startAnimations() {
        // Scan line loop: top to bottom in 3 seconds
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            scanProgress = 1.0
        }

        // Glow pulse: 1.5 seconds, ping-pong
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowPulse = 1.0
        }

        // Dot cycling every 0.5s
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            dotCount = (dotCount % 3) + 1
        }
    }
}

// MARK: - Spinning arc indicator

private struct SpinnerArc: View {
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.red.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

#Preview {
    FaceScanAnimationView(
        completedEngines: .constant([.googleLens]),
        totalEngines: 4
    )
}
