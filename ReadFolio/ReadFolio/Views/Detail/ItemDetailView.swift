import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ItemDetailViewModel
    @State private var showingEdit    = false
    @State private var showDeleteAlert = false

    init(item: ReadingItem) {
        _vm = State(initialValue: ItemDetailViewModel(item: item))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                Divider().padding(.vertical, 8)
                detailsSection.padding(.horizontal)
                if !vm.item.notes.isEmpty {
                    notesSection.padding(.horizontal)
                }
                tagsSection.padding(.horizontal)
                readingHistorySection.padding(.horizontal)
            }
        }
        .navigationTitle(vm.item.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showingEdit) {
            AddEditView(item: vm.item) {}
        }
        .alert("Eliminare questo elemento?", isPresented: $showDeleteAlert) {
            Button("Elimina", role: .destructive) {
                Task {
                    await vm.delete()
                    dismiss()
                }
            }
            Button("Annulla", role: .cancel) {}
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            CoverImageView(data: vm.item.coverImageData, url: vm.item.coverImageURL, size: 120)
                .shadow(radius: 4)
            VStack(alignment: .leading, spacing: 6) {
                Text(vm.item.title).font(.title2.bold())
                if !vm.item.author.isEmpty {
                    Text(vm.item.author).font(.subheadline).foregroundStyle(.secondary)
                }
                StatusBadgeView(status: vm.item.status).padding(.top, 2)
                if vm.item.rating > 0 {
                    StarRatingView(rating: .constant(vm.item.rating), interactive: false)
                }
                HStack(spacing: 4) {
                    Image(systemName: vm.item.contentType.systemImage)
                    Text(vm.item.contentType.rawValue)
                }
                .font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding()
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !vm.item.publisher.isEmpty   { detailRow(label: "Editore",      value: vm.item.publisher,   icon: "building.2") }
            if !vm.item.illustrator.isEmpty { detailRow(label: "Illustratore", value: vm.item.illustrator, icon: "paintbrush") }
            if !vm.item.genre.isEmpty       { detailRow(label: "Genere",       value: vm.item.genre,       icon: "tag") }
            if let v = vm.item.volume       { detailRow(label: "Volume",       value: "\(v)",              icon: "number") }
            if let i = vm.item.issueNumber  { detailRow(label: "Numero",       value: "\(i)",              icon: "doc.text") }
            if let c = vm.item.chapter      { detailRow(label: "Capitolo",     value: "\(c)",              icon: "list.number") }
            if !vm.item.edition.isEmpty     { detailRow(label: "Edizione",     value: vm.item.edition,     icon: "books.vertical") }
            if let isbn = vm.item.isbn, !isbn.isEmpty { detailRow(label: "ISBN", value: isbn,              icon: "barcode") }
        }
    }

    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
            Text(label + ":").foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(value).fontWeight(.medium)
            Spacer()
        }
        .font(.subheadline)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Note", systemImage: "note.text").font(.headline)
            Text(vm.item.notes)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.top, 8)
    }

    private var tagsSection: some View {
        Group {
            if !vm.item.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tag", systemImage: "tag").font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(vm.item.tags, id: \.self) { tag in
                                TagChipView(name: tag)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var readingHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Cronologia lettura", systemImage: "calendar").font(.headline)
            ReadingHistoryView(item: vm.item, duration: vm.readingDuration)
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showingEdit = true } label: {
                Image(systemName: "pencil")
            }
            .keyboardShortcut("e", modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await vm.toggleFavorite() }
            } label: {
                Image(systemName: vm.item.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(vm.item.isFavorite ? .yellow : .primary)
            }
        }
        ToolbarItem(placement: .destructiveAction) {
            Button(role: .destructive) { showDeleteAlert = true } label: {
                Image(systemName: "trash")
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
    }
}
