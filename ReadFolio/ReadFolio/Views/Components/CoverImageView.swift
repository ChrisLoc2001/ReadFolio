//
//  CoverImageView.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 31/05/2026.
//


import SwiftUI

struct CoverImageView: View {
    /// Immagine locale appena scelta (anteprima prima dell'upload). Ha priorità sull'URL.
    let data: Data?
    /// URL della copertina su Firebase Storage.
    var url: String? = nil
    let size: CGFloat

    init(data: Data?, url: String? = nil, size: CGFloat) {
        self.data = data
        self.url  = url
        self.size = size
    }

    var body: some View {
        Group {
            if let data, let image = platformImage(from: data) {
                image
                    .resizable()
                    .scaledToFill()
            } else if let url, let remote = URL(string: url) {
                AsyncImage(url: remote) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        placeholder.overlay { ProgressView() }
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size * 1.4)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
    }

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

    private func platformImage(from data: Data) -> Image? {
        guard let decoded = CoverImageCache.image(for: data) else { return nil }
        #if canImport(UIKit)
        return Image(uiImage: decoded)
        #elseif canImport(AppKit)
        return Image(nsImage: decoded)
        #endif
    }
}
