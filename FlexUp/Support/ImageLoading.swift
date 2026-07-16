import SwiftUI
import UIKit
import ImageIO

/// Fast image handling. Full-resolution camera JPEGs decoded on the main
/// thread were the app's biggest source of lag — everything here exists to
/// keep image work off the main thread and keep decoded sizes small.
enum ImageLoader {

    private static let cache = NSCache<NSString, UIImage>()

    /// Load a downsampled thumbnail off the main thread, cached by file+size.
    /// ImageIO decodes straight to the target size instead of inflating the
    /// full-resolution image first.
    static func thumbnail(at url: URL, maxPixel: CGFloat) async -> UIImage? {
        let key = "\(url.lastPathComponent)-\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image: UIImage? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                    kCGImageSourceShouldCacheImmediately: true,
                ]
                guard let source = CGImageSourceCreateImageSource(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }

        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }
}

extension UIImage {
    /// JPEG data capped to a sane edge length. Camera output is 12MP+;
    /// nothing in the app needs more than ~1600px, and smaller files keep
    /// both disk writes and later decodes fast.
    func flexJPEGData(maxEdge: CGFloat = 1600, quality: CGFloat = 0.75) -> Data? {
        let longEdge = max(size.width, size.height)
        guard longEdge > maxEdge else {
            return jpegData(compressionQuality: quality)
        }
        let scale = maxEdge / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

/// Async, cached photo view — shows a quiet placeholder, then the thumbnail.
/// Replaces synchronous UIImage(contentsOfFile:) calls in grids and rows.
struct AsyncPhotoView: View {
    let url: URL
    var maxPixel: CGFloat = 500

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.card
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(Theme.inkSubtle.opacity(0.5))
                }
            }
        }
        .task(id: url) {
            image = await ImageLoader.thumbnail(at: url, maxPixel: maxPixel)
        }
    }
}
