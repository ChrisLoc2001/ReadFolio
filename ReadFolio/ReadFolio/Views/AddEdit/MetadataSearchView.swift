import SwiftUI

struct MetadataSearchView: View {
    @Bindable var vm: AddEditViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                searchBar

                if vm.isSearchingMetadata {
                    ProgressView("Ricerca in corso…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.metadataError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.metadataResults.isEmpty && !vm.metadataSearchQuery.isEmpty {
                    Text("Nessun risultato. Prova con un'altra ricerca.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    resultsList
                }
            }
            .navigationTitle("Cerca metadati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Titolo, autore, ISBN…", text: $vm.metadataSearchQuery)
                .onSubmit { Task { await vm.searchMetadata() } }
                .autocorrectionDisabled()
            if !vm.metadataSearchQuery.isEmpty {
                Button {
                    vm.metadataSearchQuery = ""
                    vm.metadataResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    private var resultsList: some View {
        List(vm.metadataResults) { book in
            Button {
                Task {
                    await vm.applyMetadata(book)
                    dismiss()
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !book.authors.isEmpty {
                        Text(book.authors.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !book.publisher.isEmpty {
                        Text(book.publisher)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if let year = book.publishYear {
                        Text("\(year)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
