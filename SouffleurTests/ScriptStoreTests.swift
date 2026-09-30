import Foundation
import XCTest
@testable import Souffleur

@MainActor
final class ScriptStoreTests: XCTestCase {
    func testRoundTripAndOffset() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ScriptStore(directory: directory)
        let created = store.create(body: "Bonjour le monde")
        store.setLastCharOffset(id: created.id, 8)
        store.flush()

        let reopened = ScriptStore(directory: directory)
        XCTAssertEqual(reopened.scripts.count, 1)
        XCTAssertEqual(reopened.script(id: created.id)?.body, "Bonjour le monde")
        XCTAssertEqual(reopened.script(id: created.id)?.lastCharOffset, 8)
        XCTAssertEqual(reopened.script(id: created.id)?.wordCount, 3)
        XCTAssertEqual(reopened.script(id: created.id)?.createdAt.timeIntervalSince1970 ?? 0,
                       created.createdAt.timeIntervalSince1970, accuracy: 1)
    }

    func testSortsByMostRecentModification() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ScriptStore(directory: directory)
        let first = store.create(body: "Premier")
        let second = store.create(body: "Second")
        XCTAssertEqual(store.scripts.first?.id, second.id)

        store.update(id: first.id, body: "Premier modifié")
        XCTAssertEqual(store.scripts.first?.id, first.id)
    }

    func testTitleUsesFirstNonemptyLineAndEightyCharacters() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ScriptStore(directory: directory)
        XCTAssertEqual(store.create(body: " \n\t\nTexte utile\nSuite").title, "Texte utile")
        XCTAssertEqual(store.create(body: "\n  ").title, "Sans titre")
        XCTAssertEqual(store.create(body: String(repeating: "a", count: 100)).title.count, 80)
    }

    func testDebounceAndFlush() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ScriptStore(directory: directory)
        let script = store.create(body: "Avant")
        store.update(id: script.id, body: "Après")
        XCTAssertEqual(ScriptStore(directory: directory).script(id: script.id)?.body, "Avant")

        try await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(ScriptStore(directory: directory).script(id: script.id)?.body, "Après")

        store.update(id: script.id, body: "Final")
        store.flush()
        XCTAssertEqual(ScriptStore(directory: directory).script(id: script.id)?.body, "Final")
    }

    func testCorruptFileIsRenamedAndLibraryStartsEmpty() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{invalid".utf8).write(to: directory.appendingPathComponent("library.json"))

        let store = ScriptStore(directory: directory)
        XCTAssertTrue(store.scripts.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("library.json").path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .contains { $0.hasPrefix("library.corrupt-") && $0.hasSuffix(".json") })
    }

    func testMarkdownImport() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("notes.md")
        try "# Notes\nUn essai".write(to: source, atomically: true, encoding: .utf8)

        let store = ScriptStore(directory: directory)
        let imported = try store.importFile(at: source)
        XCTAssertEqual(imported.body, "# Notes\nUn essai")
        let reopened = ScriptStore(directory: directory).script(id: imported.id)
        XCTAssertEqual(reopened?.id, imported.id)
        XCTAssertEqual(reopened?.body, imported.body)
    }

    func testRemovingEmptyLinesPreservesStoredText() {
        let body = "Premier\n  \nDeuxième\r\n\nTroisième"
        XCTAssertEqual(ScriptStore.removingEmptyLines(body), "Premier\nDeuxième\nTroisième")
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("SouffleurTests-\(UUID().uuidString)", isDirectory: true)
    }
}
