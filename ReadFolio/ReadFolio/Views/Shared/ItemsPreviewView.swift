import SwiftUI

/// Lista di sola lettura di ReadingItem, usata per la navigazione dalle stat bar.
struct ItemsPreviewView: View {
    let items: [ReadingItem]
    let title: String

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "Nessun elemento",
                    systemImage: "books.vertical",
                    description: Text("La lista è vuota.")
                )
            } else {
                ForEach(items) { item in
                    LibraryItemRow(item: item)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Versione automanente per il profilo proprio: carica i libri completati da Firestore.
struct OwnReadBooksView: View {
    @State private var items: [ReadingItem] = []
    @State private var isLoading = false
    private let repo = ItemRepository()

    var body: some View {
        ItemsPreviewView(items: items, title: "Libri letti")
            .overlay { if isLoading { ProgressView() } }
            .task {
                isLoading = true
                items = (try? await repo.fetchByStatus(.completed)) ?? []
                isLoading = false
            }
            .refreshable {
                items = (try? await repo.fetchByStatus(.completed)) ?? []
            }
    }
}
