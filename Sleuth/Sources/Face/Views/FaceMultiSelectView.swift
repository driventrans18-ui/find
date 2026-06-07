import SwiftUI

struct FaceMultiSelectView: View {
    let originalImage: UIImage
    let faces: [DetectedFace]
    let onSelect: (DetectedFace) -> Void
    let onCancel: () -> Void

    @State private var selectedIndex: Int? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                photoWithBoxes
                faceStrip
                confirmButton
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .padding(10).background(Color.white.opacity(0.1)).clipShape(Circle())
            }
            Spacer()
            Text("SELECT A FACE")
                .font(.system(.subheadline, design: .monospaced)).fontWeight(.bold)
                .foregroundStyle(.white).tracking(2)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var photoWithBoxes: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: originalImage)
                    .resizable().scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                ForEach(faces.indices, id: \.self) { i in
                    let face = faces[i]
                    let box = visionToView(face.normalizedBox, in: geo.size, imageSize: originalImage.size)
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(selectedIndex == i ? Color.cyan : Color.red, lineWidth: 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.clear))
                        Text("\(i + 1)")
                            .font(.system(.caption2, design: .monospaced)).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(selectedIndex == i ? Color.cyan : Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .offset(x: 0, y: -20)
                    }
                    .frame(width: box.width, height: box.height)
                    .position(x: box.midX, y: box.midY)
                    .onTapGesture { selectedIndex = i }
                }
            }
        }
        .frame(maxHeight: 340)
        .clipped()
    }

    private var faceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(faces.indices, id: \.self) { i in
                    let face = faces[i]
                    let isSelected = selectedIndex == i
                    Image(uiImage: face.croppedImage)
                        .resizable().scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.cyan : Color.white.opacity(0.2), lineWidth: isSelected ? 2.5 : 1))
                        .overlay(alignment: .topTrailing) {
                            Text("\(i + 1)")
                                .font(.system(.caption2, design: .monospaced)).fontWeight(.bold)
                                .foregroundStyle(.white).padding(4)
                                .background(isSelected ? Color.cyan : Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .offset(x: 4, y: -4)
                        }
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.spring(duration: 0.2), value: isSelected)
                        .onTapGesture { selectedIndex = i }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
    }

    private var confirmButton: some View {
        Button {
            if let idx = selectedIndex { onSelect(faces[idx]) }
        } label: {
            Text("SEARCH THIS FACE")
                .font(.system(.subheadline, design: .monospaced)).fontWeight(.bold)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(selectedIndex != nil ? Color.cyan : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(selectedIndex == nil)
        .padding(.horizontal, 20).padding(.bottom, 32)
    }

    // Convert Vision bounding box (bottom-left origin, normalized) to view coordinates
    private func visionToView(_ box: CGRect, in viewSize: CGSize, imageSize: CGSize) -> CGRect {
        // Figure out the actual rendered image rect inside the view (scaledToFit)
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        let renderedSize: CGSize
        let offset: CGPoint
        if imageAspect > viewAspect {
            renderedSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
            offset = CGPoint(x: 0, y: (viewSize.height - renderedSize.height) / 2)
        } else {
            renderedSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
            offset = CGPoint(x: (viewSize.width - renderedSize.width) / 2, y: 0)
        }
        let x = offset.x + box.minX * renderedSize.width
        let y = offset.y + (1 - box.maxY) * renderedSize.height
        return CGRect(x: x, y: y, width: box.width * renderedSize.width, height: box.height * renderedSize.height)
    }
}
