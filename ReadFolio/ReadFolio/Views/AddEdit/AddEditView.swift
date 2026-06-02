import SwiftUI
import PhotosUI

struct AddEditView: View {
    @Environment(\.dismiss) private var dismiss

    let item:   ReadingItem?
    let onSave: () async -> Void

    @State private var vm                  = AddEditViewModel()
    @State private var showingMetadataSearch = false
    @State private var selectedPhoto:      PhotosPickerItem? = nil
    @FocusState private var focusedField:  FormField?

    enum FormField: Hashable {
        case title, author, illustrator, publisher, edition, genre, notes, isbn, tag
    }

    var body: some View {
        NavigationStack {
            Form {
                coverSection
                basicInfoSection
                statusRatingSection
                creatorsSection
                publicationSection
                datesSection
                notesSection
                tagsSection
                metadataSection
            }
            .navigationTitle(vm.isEditing ? "Modifica" : "Aggiungi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                        .keyboardShortcut(.escape)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        Task { await saveAndDismiss() }
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(vm.title.isEmpty || vm.isSaving)
                }
            }
            .sheet(isPresented: $showingMetadataSearch) {
                MetadataSearchView(vm: vm)
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task { await loadPhoto(from: newItem) }
            }
        }
        .onAppear { vm.setup(item: item) }
    }

    private var coverSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    CoverImageView(data: vm.coverImageData, size: 100).shadow(radius: 3)
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Scegli copertina", systemImage: "photo").font(.caption)
                    }
                    .buttonStyle(.borderless)
                    if vm.coverImageData != nil {
                        Button("Rimuovi", role: .destructive) { vm.coverImageData = nil }
                            .font(.caption).buttonStyle(.borderless)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var basicInfoSection: some View {
        Section("Informazioni base") {
            TextField("Titolo *", text: $vm.title).focused($focusedField, equals: .title)
            if let err = vm.validationError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            Picker("Tipo", selection: $vm.contentType) {
                ForEach(ContentType.allCases) { type in
                    Label(type.rawValue, systemImage: type.systemImage).tag(type)
                }
            }
            TextField("ISBN", text: $vm.isbn).keyboardType(.numberPad)
        }
    }

    private var statusRatingSection: some View {
        Section("Stato e valutazione") {
            Picker("Stato", selection: $vm.status) {
                ForEach(ReadingStatus.allCases) { s in
                    Label(s.rawValue, systemImage: s.systemImage).tag(s)
                }
            }
            HStack {
                Text("Valutazione")
                Spacer()
                StarRatingView(rating: $vm.rating, interactive: true)
            }
            Toggle(isOn: $vm.isFavorite) {
                Label("Preferito", systemImage: "star.fill")
            }
        }
    }

    private var creatorsSection: some View {
        Section("Autori") {
            TextField("Autore",      text: $vm.author).focused($focusedField, equals: .author)
            TextField("Illustratore", text: $vm.illustrator).focused($focusedField, equals: .illustrator)
            TextField("Editore",     text: $vm.publisher).focused($focusedField, equals: .publisher)
        }
    }

    private var publicationSection: some View {
        Section("Pubblicazione") {
            TextField("Volume",   text: $vm.volume).keyboardType(.numberPad)
            TextField("Numero",   text: $vm.issueNumber).keyboardType(.numberPad)
            TextField("Capitolo", text: $vm.chapter).keyboardType(.numberPad)
            TextField("Edizione", text: $vm.edition).focused($focusedField, equals: .edition)
            TextField("Genere",   text: $vm.genre).focused($focusedField, equals: .genre)
        }
    }

    private var datesSection: some View {
        Section("Date di lettura") {
            DatePickerRow(label: "Inizio lettura", date: $vm.startDate, icon: "play.circle")
            DatePickerRow(label: "Fine lettura",   date: $vm.endDate,   icon: "checkmark.circle")
        }
    }

    private var notesSection: some View {
        Section("Note") {
            TextEditor(text: $vm.notes)
                .frame(minHeight: 80)
                .focused($focusedField, equals: .notes)
        }
    }

    private var tagsSection: some View {
        Section("Tag") {
            HStack {
                TextField("Nuovo tag", text: $vm.tagInput)
                    .focused($focusedField, equals: .tag)
                    .onSubmit { vm.addTag() }
                Button("Aggiungi", action: vm.addTag)
                    .buttonStyle(.borderless)
                    .disabled(vm.tagInput.isEmpty)
            }
            if !vm.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(vm.tags, id: \.self) { tag in
                            TagChipView(name: tag, removable: true) { vm.removeTag(tag) }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var metadataSection: some View {
        Section {
            Button {
                showingMetadataSearch = true
            } label: {
                Label("Cerca metadati online", systemImage: "magnifyingglass")
            }
        } footer: {
            Text("Cerca su Google Books, MangaDex o Comic Vine.")
        }
    }

    private func saveAndDismiss() async {
        await vm.save()
        if vm.validationError == nil {
            await onSave()
            dismiss()
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            vm.coverImageData = ImageService.processImage(data)
        }
    }
}
// MARK: - DatePickerRow

struct DatePickerRow: View {
    let label: String
    @Binding var date: Date?
    let icon: String

    @State private var hasDate:   Bool = false
    @State private var pickerDate: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $hasDate) {
                Label(label, systemImage: icon)
            }
            .onChange(of: hasDate) { _, newVal in
                date = newVal ? pickerDate : nil
            }
            .onChange(of: date) { _, newVal in
                if let d = newVal { pickerDate = d; hasDate = true }
                else { hasDate = false }
            }
            .onAppear {
                if let d = date { pickerDate = d; hasDate = true }
            }

            if hasDate {
                DatePicker("", selection: $pickerDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: pickerDate) { _, d in date = d }
            }
        }
    }
}
