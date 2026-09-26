import SwiftUI
import UIKit
import ImageIO

/// Photos from the FlexUp server (avatars, post pictures). Downloaded once,
/// downsampled off the main thread, and kept in memory — the same rules as
/// `AsyncPhotoView` for local photos. The server marks images immutable, so
/// `URLCache` also keeps them on disk between launches.
enum RemoteImageLoader {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        return cache
    }()

    static func cached(_ url: URL, maxPixel: CGFloat) -> UIImage? {
        cache.object(forKey: key(url, maxPixel))
    }

    static func load(_ url: URL, maxPixel: CGFloat) async -> UIImage? {
        let cacheKey = key(url, maxPixel)
        if let hit = cache.object(forKey: cacheKey) { return hit }
        guard let result = try? await URLSession.shared.data(from: url),
              (result.1 as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let data = result.0
        let image = await Task.detached(priority: .userInitiated) {
            RemoteImageLoader.downsample(data, maxPixel: maxPixel)
        }.value
        if let image { cache.setObject(image, forKey: cacheKey) }
        return image
    }

    private static func key(_ url: URL, _ maxPixel: CGFloat) -> NSString {
        "\(url.absoluteString)#\(Int(maxPixel))" as NSString
    }

    fileprivate static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// A server photo that fills its frame; the caller sets size and clipping.
struct RemoteImageView: View {
    let url: URL?
    var maxPixel: CGFloat = 900

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Theme.accentSoft
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else if url != nil {
                ProgressView()
            }
        }
        .clipped()
        .task(id: url) {
            guard let url else { image = nil; return }
            if let hit = RemoteImageLoader.cached(url, maxPixel: maxPixel) {
                image = hit
                return
            }
            let loaded = await RemoteImageLoader.load(url, maxPixel: maxPixel)
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }
}

/// Someone's profile photo, or their initials until they add one. `ring`
/// draws the gradient ring from the profile screen.
struct ProfileAvatar: View {
    @Environment(AppStore.self) private var store
    let name: String
    let avatarId: String?
    var size: CGFloat = 40
    var ring = false

    @State private var image: UIImage?

    private var url: URL? { store.community.imageURL(avatarId) }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                AvatarCircle(name: name.isEmpty ? "?" : name, size: size)
            }
        }
        .padding(ring ? max(2, size * 0.035) : 0)
        .background {
            if ring {
                Circle().fill(Theme.background)
            }
        }
        .overlay {
            if ring {
                Circle().strokeBorder(ProfileAvatar.ringGradient, lineWidth: max(2, size * 0.03))
            }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            let pixels = size * 3
            if let hit = RemoteImageLoader.cached(url, maxPixel: pixels) {
                image = hit
            } else {
                image = await RemoteImageLoader.load(url, maxPixel: pixels)
            }
        }
    }

    static let ringGradient = LinearGradient(
        colors: [Color(light: 0x3B6FD8, dark: 0x6D9BFF), Theme.accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension ProfileAvatar {
    init(user: CommunityUser, size: CGFloat = 40, ring: Bool = false) {
        self.init(name: user.name, avatarId: user.avatarId, size: size, ring: ring)
    }
}
