//
//  FilterSortView.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 31/05/2026.
//


import SwiftUI

struct FilterSortView: View {
    @Binding var selectedType: ContentType?
    @Binding var selectedStatus: ReadingStatus?
    @Binding var sortOption: SortOption
    @Binding var sortAscending: Bool
    @Binding var showFavoritesOnly: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Tipo
                Section("Tipo di contenuto") {
                    allTypesButton
                    ForEach(ContentType.allCases) { type in
                        filterRow(
                            label: type.rawValue,
                            icon: type.systemImage,
                            isSelected: selectedType == type
                        ) {
                            selectedType = selectedType == type ? nil : type
                        }
                    }
                }

                // MARK: - Stato
                Section("Stato di lettura") {
                    allStatusButton
                    ForEach(ReadingStatus.allCases) { status in
                        filterRow(
                            label: status.rawValue,
                            icon: status.systemImage,
                            color: status.color,
                            isSelected: selectedStatus == status
                        ) {
                            selectedStatus = selectedStatus == status ? nil : status
                        }
                    }
                }

                // MARK: - Preferiti
                Section {
                    Toggle(isOn: $showFavoritesOnly) {
                        Label("Solo preferiti", systemImage: "star.fill")
                    }
                }

                // MARK: - Ordinamento
                Section("Ordina per") {
                    Picker("Criterio", selection: $sortOption) {
                        ForEach(SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.inline)

                    Toggle(isOn: $sortAscending) {
                        Label(
                            sortAscending ? "Crescente" : "Decrescente",
                            systemImage: sortAscending ? "arrow.up" : "arrow.down"
                        )
                    }
                }

                // MARK: - Reset
                Section {
                    Button("Reimposta filtri", role: .destructive) {
                        selectedType = nil
                        selectedStatus = nil
                        showFavoritesOnly = false
                    }
                }
            }
            .navigationTitle("Filtri e ordinamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }

    private var allTypesButton: some View {
        filterRow(
            label: "Tutti i tipi",
            icon: "square.grid.2x2",
            isSelected: selectedType == nil
        ) {
            selectedType = nil
        }
    }

    private var allStatusButton: some View {
        filterRow(
            label: "Tutti gli stati",
            icon: "circle.grid.cross",
            isSelected: selectedStatus == nil
        ) {
            selectedStatus = nil
        }
    }

    private func filterRow(
        label: String,
        icon: String,
        color: Color = .accentColor,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(label, systemImage: icon)
                    .foregroundStyle(isSelected ? color : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(color)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
