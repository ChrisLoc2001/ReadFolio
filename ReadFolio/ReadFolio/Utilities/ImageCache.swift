import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Cache in memoria delle immagini di copertina già decodificate.
///
/// Senza cache, `CoverImageView` decodifica il JPEG (`UIImage(data:)`) dentro `body`
/// ad ogni redraw e per ogni riga della lista → jank durante lo scroll. Qui decodifichiamo
/// una sola volta per `Data` e riusiamo l'immagine decodificata.
enum CoverImageCache {

    private static let cache: NSCache<NSNumber, PlatformImage> = {
        let c = NSCache<NSNumber, PlatformImage>()
        c.countLimit = 300
        return c
    }()

    static func image(for data: Data) -> PlatformImage? {
        let key = NSNumber(value: data.hashValue)
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = PlatformImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
