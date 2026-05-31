//
//  ExportImportService.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 31/05/2026.
//


import Foundation
import SwiftData

struct ExportImportService {

    // MARK: - Export

    static func exportJSON(items: [ReadingItem]) throws -> Data {
        let dtos = items.map { ItemDTO(from: $0) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(dtos)
    }

    // MARK: - Import

    static func importJSON(data: Data, context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dtos = try decoder.decode([ItemDTO].self, from: data)

        for dto in dtos {
            let item = dto.toReadingItem()
            context.insert(item)
        }
        try context.save()
        return dtos.count
    }
}

// MARK: - DTO

struct ItemDTO: Codable {
    var title: String
    var contentType: String
    var author: String
    var illustrator: String
    var publisher: String
    var volume: Int?
    var issueNumber: Int?
    var chapter: Int?
    var edition: String
    var status: String
    var rating: Int
    var isFavorite: Bool
    var startDate: Date?
    var endDate: Date?
    var notes: String
    var genre: String
    var tags: [String]
    var isbn: String?
    var openLibraryKey: String?
    var createdAt: Date
    var updatedAt: Date

    init(from item: ReadingItem) {
        title = item.title
        contentType = item.contentType.rawValue
        author = item.author
        illustrator = item.illustrator
        publisher = item.publisher
        volume = item.volume
        issueNumber = item.issueNumber
        chapter = item.chapter
        edition = item.edition
        status = item.status.rawValue
        rating = item.rating
        isFavorite = item.isFavorite
        startDate = item.startDate
        endDate = item.endDate
        notes = item.notes
        genre = item.genre
        tags = item.tags.map { $0.name }
        isbn = item.isbn
        openLibraryKey = item.openLibraryKey
        createdAt = item.createdAt
        updatedAt = item.updatedAt
    }

    func toReadingItem() -> ReadingItem {
        ReadingItem(
            title: title,
            contentType: ContentType(rawValue: contentType) ?? .book,
            author: author,
            illustrator: illustrator,
            publisher: publisher,
            volume: volume,
            issueNumber: issueNumber,
            chapter: chapter,
            edition: edition,
            status: ReadingStatus(rawValue: status) ?? .toRead,
            rating: rating,
            isFavorite: isFavorite,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            genre: genre,
            tags: [], // i tag vengono ricreati separatamente per evitare duplicati
            openLibraryKey: openLibraryKey, isbn: isbn
        )
    }
}
