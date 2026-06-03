import SwiftUI

// Cache in-memory per URL remoti (separata da quella per dati locali).
private let remoteImageCache = NSCache<NSString, PlatformImage>()

struct CoverImageView: View {
    let data: Data?
    var url: String? = nil
    let size: CGFloat

    @State private var downloaded: PlatformImage? = nil

    init(data: Data?, url: String? = nil, size: CGFloat) {
        self.data = data
        self.url  = url
        self.size = size
    }

    var body: some View {
        Group {
            if let data, let image = localImage(from: data) {
                image.resizable().scaledToFill()
            } else if let img = downloaded {
                platformImage(img).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size * 1.4)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
        .task(id: url) {
            await loadRemoteImage()
        }
    }

    // MARK: - Private

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "book.closed")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: size * 0.35))
            }
    }

    private var cornerRadius: CGFloat { size * 0.1 }

    private func localImage(from data: Data) -> Image? {
        guard let img = CoverImageCache.image(for: data) else { return nil }
        return platformImage(img)
    }

    private func platformImage(_ img: PlatformImage) -> Image {
        #if canImport(UIKit)
        return Image(uiImage: img)
        #elseif canImport(AppKit)
        return Image(nsImage: img)
        #endif
    }

    private func loadRemoteImage() async {
        guard data == nil, let urlString = url, let remote = URL(string: urlString) else { return }

        // Controlla la cache prima di scaricare.
        if let cached = remoteImageCache.object(forKey: urlString as NSString) {
            downloaded = cached
            return
        }

        guard let (imageData, response) = try? await URLSession.shared.data(from: remote),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let img = PlatformImage(data: imageData) else { return }

        remoteImageCache.setObject(img, forKey: urlString as NSString)
        downloaded = img
    }
}
