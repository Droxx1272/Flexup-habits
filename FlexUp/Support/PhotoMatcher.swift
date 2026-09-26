import UIKit
import Vision

/// Decides whether a morning photo shows the same spot as the reference
/// photo taken at setup. Runs entirely on the phone with Apple's Vision
/// feature prints: nothing is uploaded.
enum PhotoMatcher {
    /// Feature-print distance (revision 2, roughly 0...2) under which two
    /// photos count as the same place. Same spot from a similar angle lands
    /// well below this; a different room lands well above it. Loosen it if
    /// real mornings (dim light, different angle) fail too often.
    static let matchThreshold: Float = 0.7

    enum Outcome {
        case match
        case noMatch
        /// Vision couldn't read one of the photos. Not the user's fault.
        case failed
    }

    static func compare(_ photo: UIImage, toReferenceAt url: URL) async -> Outcome {
        let prepared = normalized(photo)
        return await Task.detached(priority: .userInitiated) {
            guard
                let referenceImage = UIImage(contentsOfFile: url.path).map(normalized),
                let reference = featurePrint(of: referenceImage),
                let candidate = featurePrint(of: prepared)
            else { return .failed }

            var distance: Float = 0
            do {
                try candidate.computeDistance(&distance, to: reference)
            } catch {
                return .failed
            }
            return distance <= matchThreshold ? .match : .noMatch
        }.value
    }

    private static func featurePrint(of image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision2
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        return request.results?.first
    }

    /// Small and upright: camera photos carry an orientation flag Vision
    /// would otherwise ignore, and 512px is plenty for a scene comparison.
    private static func normalized(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return image }
        let scale = min(1, 512 / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
