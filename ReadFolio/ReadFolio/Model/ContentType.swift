import Foundation

enum ContentType: String, Codable, CaseIterable, Identifiable {
    case book    = "Libro"
    case manga   = "Manga"
    case comic   = "Fumetto"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .book:  return "book.fill"
        case .manga: return "doc.text.image.fill"
        case .comic: return "rectangle.stack.fill"
        }
    }
}
