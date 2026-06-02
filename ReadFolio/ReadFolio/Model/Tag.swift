import Foundation

struct Tag: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var colorHex: String
    var userID: String

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String = "#6366F1",
        userID: String = ""
    ) {
        self.id       = id
        self.name     = name
        self.colorHex = colorHex
        self.userID   = userID
    }
}
