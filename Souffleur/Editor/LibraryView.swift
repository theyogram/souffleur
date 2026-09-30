import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Bindable private var store: ScriptStore
    private let selection: Binding<UUID?>
    private let onOpenInPrompter: (UUID) -> Void

    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var importError: String?

    init(store: ScriptStore, selection: Binding<UUID?>, onOpenInPrompter: @escaping (UUID) -> Void) {
        self.store = store
        self.selection = selection
        self.onOpenInPrompter = onOpenInPrompter
    }

    private var filteredScripts: [Script] {
        guard !searchText.isEmpty else { return store.scripts }
        return store.scripts.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.body.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedScript: Script? {
        guard let id = selection.wrappedValue else { return nil }
        return store.script(id: id)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                ForEach(filteredScripts) { script in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(script.title)
                            .font(.headline)
                            .lineLimit(1)
                        HStack {
                            Text(RelativeDateTimeFormatter().localizedString(for: script.updatedAt, relativeTo: Date()))
                            Spacer()
                            Text("\(script.wordCount) mots")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .tag(script.id)
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher des scripts")
            .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: importDroppedFiles)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let script = selectedScript {
                VStack(spacing: 0) {
                    TextEditor(text: Binding(
                        get: { store.script(id: script.id)?.body ?? "" },
                        set: { store.update(id: script.id, body: $0) }
                    ))
                    .font(.system(size: 14, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(12)

                    Divider()
                    HStack {
                        Text("\(script.wordCount) mots")
                        Spacer()
                        Text(estimatedDuration(for: script.wordCount))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                }
            } else {
                ContentUnavailableView("Aucun script sélectionné", systemImage: "text.book.closed", description: Text("Crée un script pour commencer."))
            }
        }
        .frame(minWidth: 620, minHeight: 400)
        .toolbar {
            ToolbarItemGroup {
                Button("Nouveau", systemImage: "plus", action: createEmpty)
                    .keyboardShortcut("n", modifiers: .command)
                Button("Nouveau depuis le presse-papier", systemImage: "doc.on.clipboard", action: createFromClipboard)
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Button("Supprimer", systemImage: "trash") { showingDeleteConfirmation = true }
                    .disabled(selectedScript == nil)
                Button("Ouvrir dans le prompteur", systemImage: "play.rectangle") {
                    openSelectedScript()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(selectedScript == nil)
            }
        }
        .confirmationDialog("Supprimer ce script ?", isPresented: $showingDeleteConfirmation) {
            Button("Supprimer", role: .destructive) { deleteSelectedScript() }
        } message: {
            Text("Cette action est définitive.")
        }
        .alert("Import impossible", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .onDisappear { store.flush() }
    }

    private func createEmpty() {
        selection.wrappedValue = store.create(body: "").id
    }

    private func createFromClipboard() {
        let body = NSPasteboard.general.string(forType: .string) ?? ""
        selection.wrappedValue = store.create(body: body).id
    }

    private func deleteSelectedScript() {
        guard let id = selection.wrappedValue else { return }
        store.delete(id: id)
        selection.wrappedValue = store.scripts.first?.id
    }

    private func openSelectedScript() {
        guard let id = selection.wrappedValue else { return }
        store.flush()
        onOpenInPrompter(id)
    }

    private func estimatedDuration(for wordCount: Int) -> String {
        let seconds = Int((Double(wordCount) / 150 * 60).rounded(.up))
        return "≈ \(seconds / 60) min \(seconds % 60) s à 150 mots/min"
    }

    private func importDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        for provider in matching {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                Task { @MainActor in
                    do {
                        if let error { throw error }
                        let url: URL?
                        if let data = item as? Data {
                            url = URL(dataRepresentation: data, relativeTo: nil)
                        } else {
                            url = item as? URL
                        }
                        guard let url else { throw CocoaError(.fileReadInvalidFileName) }
                        selection.wrappedValue = try store.importFile(at: url).id
                    } catch {
                        importError = error.localizedDescription
                    }
                }
            }
        }
        return !matching.isEmpty
    }
}
