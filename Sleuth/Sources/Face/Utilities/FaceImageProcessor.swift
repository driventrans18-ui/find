import UIKit
import Vision

enum FaceImageProcessorError: LocalizedError {
    case noFaceDetected, cropFailed, compressionFailed
    var errorDescription: String? {
        switch self {
        case .noFaceDetected: return "No face detected in the selected image."
        case .cropFailed: return "Failed to crop the detected face."
        case .compressionFailed: return "Failed to compress the face image."
        }
    }
}

struct DetectedFace {
    let index: Int
    let croppedImage: UIImage
    let normalizedBox: CGRect // Vision coordinates (bottom-left origin)
}

struct FaceImageProcessor {
    private static let maxBytes = 1_048_576
    private static let padding = 0.15

    // MARK: - Detect all faces, sorted largest first

    static func detectAllFaces(from image: UIImage) async throws -> [DetectedFace] {
        guard let cgImage = image.cgImage else { throw FaceImageProcessorError.cropFailed }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { req, err in
                if let err { continuation.resume(throwing: err); return }
                guard let obs = req.results as? [VNFaceObservation], !obs.isEmpty else {
                    continuation.resume(returning: [])
                    return
                }

                // Sort by area descending (largest face first)
                let sorted = obs.sorted {
                    ($0.boundingBox.width * $0.boundingBox.height) > ($1.boundingBox.width * $1.boundingBox.height)
                }

                var faces: [DetectedFace] = []
                for (index, observation) in sorted.enumerated() {
                    let box = padded(observation.boundingBox)
                    guard let cropped = crop(cgImage, box: box) else { continue }
                    faces.append(DetectedFace(
                        index: index,
                        croppedImage: cropped,
                        normalizedBox: observation.boundingBox
                    ))
                }

                if faces.isEmpty {
                    continuation.resume(throwing: FaceImageProcessorError.cropFailed)
                } else {
                    continuation.resume(returning: faces)
                }
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do { try handler.perform([request]) } catch { continuation.resume(throwing: error) }
        }
    }

    // MARK: - Detect and crop single (largest) face

    static func detectAndCropFace(from image: UIImage) async throws -> UIImage {
        let faces = try await detectAllFaces(from: image)
        guard let first = faces.first else { throw FaceImageProcessorError.noFaceDetected }
        return first.croppedImage
    }

    // MARK: - Compression

    static func compressToMaxSize(_ image: UIImage) throws -> Data {
        var q = 0.9
        while q > 0 {
            if let data = image.jpegData(compressionQuality: q), data.count <= maxBytes { return data }
            q -= 0.1
        }
        throw FaceImageProcessorError.compressionFailed
    }

    // MARK: - Private helpers

    private static func padded(_ box: CGRect) -> CGRect {
        let x = max(0, box.minX - padding * box.width)
        let y = max(0, box.minY - padding * box.height)
        let w = min(1 - x, box.width * (1 + 2 * padding))
        let h = min(1 - y, box.height * (1 + 2 * padding))
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private static func crop(_ cg: CGImage, box: CGRect) -> UIImage? {
        let pw = CGFloat(cg.width), ph = CGFloat(cg.height)
        // Vision box origin is bottom-left; UIKit/CGImage origin is top-left
        let rect = CGRect(x: box.minX * pw, y: (1 - box.maxY) * ph, width: box.width * pw, height: box.height * ph)
        return cg.cropping(to: rect).map { UIImage(cgImage: $0) }
    }
}
