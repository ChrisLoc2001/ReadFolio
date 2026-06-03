import SwiftUI

struct MetadataSearchView: View {
    @Bindable var vm: AddEditViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sourceSelector
                    .padding(.horizontal)
                    .padding(.top, 8)

                searchBar
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                Divider()

                content
            }
            .navigationTitle("Cerca metadati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            // Carica i top risultati appena si apre la sheet
            .task { await vm.searchMetadata() }
            // Ricerca live mentre l'utente digita (debounce 600ms)
            .onChange(of: vm.metadataSearchQuery) { _, newValue in
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    // Controlla che la query non sia cambiata di nuovo durante l'attesa
                    guard vm.metadataSearchQuery == newValue else { return }
                    await vm.searchMetadata()
                }
            }
        }
    }

    // MARK: - Source selector

    private var sourceSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchSource.allCases) { source in
                    if source == .comicVine && !AppConfig.isComicVineConfigured {
                        EmptyView()
                    } else {
                        Button {
                            vm.selectedSource = source
                            Task { await vm.searchMetadata() }
                        } label: {
                            Label(source.rawValue, systemImage: source.icon)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    vm.selectedSource == source
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.15),
                                    in: Capsule()
                                )
                                .foregroundStyle(
                                    vm.selectedSource == source ? .white : .primary
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Sorgente: \(source.rawValue)")
                        .accessibilityAddTraits(vm.selectedSource == source ? .isSelected : [])
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Titolo, autore, ISBN…", text: $vm.metadataSearchQuery)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !vm.metadataSearchQuery.isEmpty {
                Button {
                    vm.metadataSearchQuery = ""
                    // Svuotando la query torna ai top results automaticamente
                    // grazie all'onChange sopra
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isSearchingMetadata {
            VStack(spacing: 12) {
                ProgressView()
                Text(vm.metadataSearchQuery.isEmpty ? "Caricamento consigliati…" : "Ricerca in corso…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else if let error = vm.metadataError {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Button("Riprova") {
                    Task { await vm.searchMetadata() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else if vm.metadataResults.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Nessun risultato trovato")
                    .font(.headline)
                Text("Prova a modificare la ricerca o cambia sorgente.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else {
            resultsList
        }
    }

    // MARK: - Results list

    private var resultsList: some View {
        List(vm.metadataResults) { result in
            Button {
                Task {
                    await vm.applyMetadata(result)
                    dismiss()
                }
            } label: {
                resultRow(result)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    private func resultRow(_ result: MediaSearchResult) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: result.coverURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure, .empty:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: result.contentType.systemImage)
                                .foregroundStyle(.tertiary)
                        }
                @unknown default:
                    Color.secondary.opacity(0.2)
                }
            }
            .frame(width: 44, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if !result.secondaryInfo.isEmpty {
                        Text(result.secondaryInfo)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    if !result.year.isEmpty {
                        Text(result.year)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                if !result.tags.isEmpty {
                    Text(result.tags.prefix(3).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.title), \(result.subtitle)")
    }
}
