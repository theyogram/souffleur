import Foundation
import Observation

@MainActor
@Observable final class ScriptStore {
    private struct LibraryFile: Codable {
        var version: Int
        var scripts: [Script]
    }

    enum ImportError: Error {
        case unsupportedFileType
    }

    nonisolated static var defaultDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return support
            .appendingPathComponent("Souffleur", isDirectory: true)
    }

    private let directory: URL
    private let fileURL: URL
    private var pendingSave: Task<Void, Never>?
    private(set) var scripts: [Script] = []
    private(set) var lastSaveError: String?

    init(directory: URL = ScriptStore.defaultDirectory) {
        self.directory = directory
        fileURL = directory.appendingPathComponent("library.json")
        load()
    }

    func script(id: UUID) -> Script? {
        scripts.first { $0.id == id }
    }

    @discardableResult func create(body: String) -> Script {
        let now = Date()
        let newScript = Script(id: UUID(), body: body, createdAt: now, updatedAt: now, lastCharOffset: 0)
        scripts.insert(newScript, at: 0)
        sortScripts()
        flush()
        return newScript
    }

    func update(id: UUID, body: String) {
        guard let index = scripts.firstIndex(where: { $0.id == id }), scripts[index].body != body else { return }
        scripts[index].body = body
        scripts[index].updatedAt = Date()
        sortScripts()
        scheduleSave()
    }

    func setLastCharOffset(id: UUID, _ offset: Int) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        let end = scripts[index].body.utf16.count
        let bounded = min(max(offset, 0), end)
        guard scripts[index].lastCharOffset != bounded else { return }
        scripts[index].lastCharOffset = bounded
        scheduleSave()
    }

    func delete(id: UUID) {
        guard scripts.contains(where: { $0.id == id }) else { return }
        scripts.removeAll { $0.id == id }
        flush()
    }

    @discardableResult func importFile(at url: URL) throws -> Script {
        guard ["txt", "md"].contains(url.pathExtension.lowercased()) else {
            throw ImportError.unsupportedFileType
        }
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        let body = try String(contentsOf: url, encoding: .utf8)
        return create(body: body)
    }

    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(LibraryFile(version: 1, scripts: scripts))
            try data.write(to: fileURL, options: .atomic)
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
        }
    }

    static func removingEmptyLines(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            lastSaveError = error.localizedDescription
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let file = try decoder.decode(LibraryFile.self, from: data)
            guard file.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
            scripts = file.scripts
            sortScripts()
        } catch {
            let stamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let backup = directory.appendingPathComponent("library.corrupt-\(stamp)-\(UUID().uuidString).json")
            do {
                try FileManager.default.moveItem(at: fileURL, to: backup)
            } catch {
                lastSaveError = error.localizedDescription
            }
            scripts = []
        }
    }

    private func sortScripts() {
        scripts.sort {
            if $0.updatedAt == $1.updatedAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }
}
