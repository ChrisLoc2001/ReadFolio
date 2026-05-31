//
//  ImageService.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 31/05/2026.
//


import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

enum ImageService {

    static let maxDimension: CGFloat = 600

    /// Ridimensiona e comprime un'immagine prima di salvarla come Data.
    static func processImage(_ data: Data) -> Data? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        let resized = resize(image: image, max: maxDimension)
        return resized.jpegData(compressionQuality: 0.8)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        let resized = resize(image: image, max: maxDimension)
        return resized.tiffRepresentation
        #endif
    }

    #if canImport(UIKit)
    private static func resize(image: UIImage, max: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > max || size.height > max else { return image }
        let ratio = min(max / size.width, max / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
    #elseif canImport(AppKit)
    private static func resize(image: NSImage, max: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > max || size.height > max else { return image }
        let ratio = min(max / size.width, max / size.height)
        let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)
        let result = NSImage(size: newSize)
        result.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        result.unlockFocus()
        return result
    }
    #endif
}
