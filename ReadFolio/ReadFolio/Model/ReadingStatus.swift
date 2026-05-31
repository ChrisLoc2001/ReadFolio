import Foundation
import SwiftUI

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case toRead     = "Da leggere"
    case reading    = "In lettura"
    case completed  = "Letto"
    case abandoned  = "Abbandonato"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .toRead:    return .blue
        case .reading:   return .orange
        case .completed: return .green
        case .abandoned: return .gray
        }
    }

    var systemImage: String {
        switch self {
        case .toRead:    return "bookmark"
        case .reading:   return "book.open"
        case .completed: return "checkmark.seal.fill"
        case .abandoned: return "xmark.circle"
        }
    }
}
