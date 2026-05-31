import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var name: String
    var colorHex: String

    @Relationship(inverse: \ReadingItem.tags)
    var items: [ReadingItem] = []

    init(name: String, colorHex: String = "#6366F1") {
        self.name = name
        self.colorHex = colorHex
    }
}
