//
//  LibraryItemRow.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 31/05/2026.
//


import SwiftUI

struct LibraryItemRow: View {
    let item: ReadingItem

    var body: some View {
        HStack(spacing: 12) {
            CoverImageView(data: item.coverImageData, size: 50)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }

                if !item.author.isEmpty {
                    Text(item.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    StatusBadgeView(status: item.status)
                    Image(systemName: item.contentType.systemImage)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if item.rating > 0 {
                        Text(String(repeating: "★", count: item.rating))
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.author.isEmpty ? "" : "di \(item.author)"), \(item.status.rawValue)")
    }
}
