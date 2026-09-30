import XCTest
@testable import Souffleur

@MainActor
final class PlaybackControllerTests: XCTestCase {
    private func makeController() throws -> (PlaybackController, ScriptStore, UserDefaults, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("souffleur-playback-\(UUID().uuidString)")
        let store = ScriptStore(directory: directory)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "souffleur-playback-\(UUID().uuidString)"))
        defaults.register(defaults: SettingsKeys.defaults)
        defaults.set(ScrollMode.constant.rawValue, forKey: SettingsKeys.scrollMode)
        return (PlaybackController(store: store, defaults: defaults), store, defaults, directory)
    }

    private func clean(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    func testConstantTransitionsAndRestartPreservesState() throws {
        let (controller, store, _, directory) = try makeController()
        defer { controller.close(); clean(directory) }
        let script = store.create(body: "Un premier mot puis un autre mot")
        controller.openScript(id: script.id)
        XCTAssertEqual(controller.state, .idle)
        controller.play()
        XCTAssertEqual(controller.state, .listening)
        XCTAssertEqual(controller.prompter.onFrame?(1), 40)
        controller.restart()
        XCTAssertEqual(controller.state, .listening)
        XCTAssertEqual(controller.cursor, -1)
        controller.pause()
        XCTAssertEqual(controller.state, .paused)
        controller.restart()
        XCTAssertEqual(controller.state, .paused)
        controller.play()
        XCTAssertEqual(controller.state, .listening)
        controller.close()
        XCTAssertEqual(controller.state, .idle)
        XCTAssertFalse(controller.prompter.isVisible)
    }

    func testResumeFromStoredCharacterOffsetWithRemovedEmptyLines() throws {
        let (controller, store, _, directory) = try makeController()
        defer { controller.close(); clean(directory) }
        let body = "alpha beta\n\ncharlie delta"
        let script = store.create(body: body)
        let tokens = Tokenizer.tokenize(body)
        store.setLastCharOffset(id: script.id, tokens[2].range.location)
        controller.openScript(id: script.id)
        XCTAssertEqual(controller.cursor, 2)
        controller.play()
        controller.pause()
        XCTAssertEqual(store.script(id: script.id)?.lastCharOffset, tokens[2].range.location)
    }

    func testEditedScriptRemapsToNearestWord() throws {
        let (controller, store, _, directory) = try makeController()
        defer { controller.close(); clean(directory) }
        let original = "alpha bravo charlie delta"
        let script = store.create(body: original)
        let oldTokens = Tokenizer.tokenize(original)
        store.setLastCharOffset(id: script.id, oldTokens[2].range.location)
        controller.openScript(id: script.id)
        XCTAssertEqual(controller.cursor, 2)
        controller.edit()
        let edited = "alpha bravo.        delta"
        store.update(id: script.id, body: edited)
        controller.openScript(id: script.id)
        XCTAssertEqual(controller.cursor, PlaybackController.nearestWordIndex(
            to: oldTokens[2].range.location, in: Tokenizer.tokenize(edited)))
        XCTAssertEqual(controller.cursor, 1)
    }
}
