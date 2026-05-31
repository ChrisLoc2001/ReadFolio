import Foundation

enum Constants {
    enum App {
        static let name = "Readfolio"
        static let version = "1.0.0"
    }

    enum OpenLibrary {
        static let baseURL = "[openlibrary.org](https://openlibrary.org)"
        static let coverBaseURL = "[covers.openlibrary.org](https://covers.openlibrary.org/b/id)"
        static let searchLimit = 20
    }

    enum Storage {
        static let maxCoverDimension: CGFloat = 600
        static let jpegQuality: CGFloat = 0.8
    }
}
