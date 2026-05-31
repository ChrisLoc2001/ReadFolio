import SwiftUI

struct CoverImageView: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let data, let image = platformImage(from: data) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: size * 0.35))
                    }
            }
        }
        .frame(width: size, height: size * 1.4)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
    }

    private var cornerRadius: CGFloat { size * 0.1 }

    private func platformImage(from data: Data) -> Image? {
        #if canImport(UIKit)
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #elseif canImport(AppKit)
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #endif
    }
}
