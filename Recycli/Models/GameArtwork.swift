import Foundation
import UIKit

enum GameArtwork {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 96 * 1_024 * 1_024
        return cache
    }()

    static func image(named name: String, in bundle: Bundle = .main) -> UIImage? {
        let key = (bundle.bundleURL.absoluteString + "|" + name) as NSString
        if let cached = cache.object(forKey: key) { return cached }

        // xtool ships named PNG files; Xcode ships a compiled asset catalog.
        // Resolve the file explicitly rather than relying on SwiftUI asset lookup.
        let image: UIImage?
        if let url = bundle.url(forResource: name, withExtension: "png") {
            image = UIImage(contentsOfFile: url.path)
        } else {
            image = UIImage(named: name, in: bundle, compatibleWith: nil)
        }
        if let image {
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            cache.setObject(image, forKey: key, cost: cost)
        }
        return image
    }
}
