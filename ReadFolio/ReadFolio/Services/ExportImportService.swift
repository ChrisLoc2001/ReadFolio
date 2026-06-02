import Foundation

struct ExportImportService {

    static func exportJSON(items: [ReadingItem]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting     = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(items)
    }

    static func importJSON(data: Data, userID: String) throws -> [ReadingItem] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var items = try decoder.decode([ReadingItem].self, from: data)
        // Assegna userID corrente agli elementi importati
        items = items.map { item in
            var i = item
            i.userID = userID
            return i
        }
        return items
    }
}
