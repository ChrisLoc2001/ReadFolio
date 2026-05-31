//
//  LibraryView.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 31/05/2026.
//


import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = LibraryViewModel()
    @State private var showingAddEdit = false
    @State private var showingFilters = false
    @State private var itemToEdit: ReadingItem? = nil
    @State private var itemToDelete: ReadingItem? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Caricamento…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.filteredItems.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .navigationTitle("Libreria")
            .searchable(text: $vm.searchText, prompt: "Cerca per titolo, autore, tag…")
            .toolbar { toolbarItems }
            .sheet(isPresented: $showingAddEdit) {
                AddEditView(item: nil) { await vm.load() }
            }
            .sheet(item: $itemToEdit) { item in
                AddEditView(item: item) { await vm.load() }
            }
            .sheet(isPresented: $showingFilters) {
                FilterSortView(
                    selectedType: $vm.selectedType,
                    selectedStatus: $vm.selectedStatus,
                    sortOption: $vm.sortOption,
                    sortAscending: $vm.sortAscending,
                    showFavoritesOnly: $vm.showFavoritesOnly
                )
            }
            .alert("Eliminare questo elemento?", isPresented: $showDeleteAlert) {
                Button("Elimina", role: .destructive) {
                    if let item = itemToDelete { vm.delete(item) }
                }
                Button("Annulla", role: .cancel) {}
            }
        }
        .task {
            vm.setup(context: context)
            await vm.load()
        }
    }

    // MARK: - List

    private var itemList: some View {
        List {
            ForEach(vm.filteredItems) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    LibraryItemRow(item: item)
                }
                .contextMenu {
                    contextMenuItems(for: item)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        itemToDelete = item
                        showDeleteAlert = true
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }

                    Button {
                        itemToEdit = item
                    } label: {
                        Label("Modifica", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        vm.toggleFavorite(item)
                    } label: {
                        Label(
                            item.isFavorite ? "Rimuovi dai preferiti" : "Aggiungi ai preferiti",
                            systemImage: item.isFavorite ? "star.slash" : "star.fill"
                        )
                    }
                    .tint(.yellow)
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: vm.filteredItems.map { $0.id })
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Nessun elemento trovato")
                .font(.title2.bold())
            Text("Aggiungi libri, manga o fumetti con il pulsante +")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingAddEdit = true
            } label: {
                Label("Aggiungi elemento", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddEdit = true
            } label: {
                Image(systemName: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityLabel("Aggiungi elemento")
        }

        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingFilters = true
            } label: {
                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("Filtri e ordinamento")
        }
    }

    private var hasActiveFilters: Bool {
        vm.selectedType != nil || vm.selectedStatus != nil || vm.showFavoritesOnly
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for item: ReadingItem) -> some View {
        Button {
            itemToEdit = item
        } label: {
            Label("Modifica", systemImage: "pencil")
        }

        Button {
            vm.toggleFavorite(item)
        } label: {
            Label(
                item.isFavorite ? "Rimuovi dai preferiti" : "Aggiungi ai preferiti",
                systemImage: item.isFavorite ? "star.slash" : "star.fill"
            )
        }

        Button {
            vm.duplicate(item)
        } label: {
            Label("Duplica", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            itemToDelete = item
            showDeleteAlert = true
        } label: {
            Label("Elimina", systemImage: "trash")
        }
    }
}
