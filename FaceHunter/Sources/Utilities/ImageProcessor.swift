import UIKit
import Vision

enum ImageProcessorError: LocalizedError {
    case noFaceDetected
    case cropFailed
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .noFaceDetected: return "No face detected in the selected image."
        case .cropFailed: return "Failed to crop the detected face."
        case .compressionFailed: return "Failed to compress the face image."
        }
    }
}

struct ImageProcessor {
    static func detectAndCropFace(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else { throw ImageProcessorError.cropFailed }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNFaceObservation],
                      let largest = observations.max(by: { a, b in
                          a.boundingBox.width * a.boundingBox.height < b.boundingBox.width * b.boundingBox.height
                      }) else {
                    continuation.resume(throwing: ImageProcessorError.noFaceDetected)
                    return
                }

                let box = paddedBoundingBox(largest.boundingBox, imageSize: image.size)
                guard let cropped = crop(cgImage: cgImage, normalizedRect: box, originalSize: image.size) else {
                    continuation.resume(throwing: ImageProcessorError.cropFailed)
                    return
                }
                continuation.resume(returning: cropped)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func compressToMaxSize(_ image: UIImage) throws -> Data {
        var quality = Constants.Image.jpegCompressionStart
        while quality > 0 {
            if let data = image.jpegData(compressionQuality: quality),
               data.count <= Constants.Image.maxFileSizeBytes {
                return data
            }
            quality -= Constants.Image.jpegCompressionStep
        }
        throw ImageProcessorError.compressionFailed
    }

    private static func paddedBoundingBox(_ box: CGRect, imageSize: CGSize) -> CGRect {
        let pad = Constants.Image.faceDetectionPadding
        let x = max(0, box.minX - pad * box.width)
        let y = max(0, box.minY - pad * box.height)
        let w = min(1 - x, box.width + 2 * pad * box.width)
        let h = min(1 - y, box.height + 2 * pad * box.height)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private static func crop(cgImage: CGImage, normalizedRect: CGRect, originalSize: CGSize) -> UIImage? {
        // Vision uses bottom-left origin; UIKit uses top-left
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        let pixelRect = CGRect(
            x: normalizedRect.minX * imageWidth,
            y: (1 - normalizedRect.maxY) * imageHeight,
            width: normalizedRect.width * imageWidth,
            height: normalizedRect.height * imageHeight
        )

        guard let croppedCG = cgImage.cropping(to: pixelRect) else { return nil }
        return UIImage(cgImage: croppedCG)
    }
}
