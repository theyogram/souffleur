import XCTest
@testable import Souffleur

final class ScriptMatcherTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_000)
    private func matcher(_ text: String, backward: Bool = false) -> ScriptMatcher {
        ScriptMatcher(tokens: Tokenizer.tokenize(text), allowBackward: backward)
    }
    private func send(_ matcher: ScriptMatcher, _ text: String, kind: TranscriptUpdate.Kind = .final, at second: Double = 0) {
        matcher.ingest(TranscriptUpdate(kind: kind, text: text, timestamp: base.addingTimeInterval(second)))
    }

    func testNormalReading() {
        let m = matcher("Astra présente une méthode simple pour raconter cette histoire")
        send(m, "Astra présente une méthode")
        XCTAssertTrue((2...4).contains(m.cursor))
    }

    func testSilence() {
        let m = matcher("Astra présente une méthode")
        send(m, "Astra présente")
        let cursor = m.cursor
        send(m, "", kind: .volatile, at: 2)
        XCTAssertEqual(m.cursor, cursor)
    }

    func testImprovisationDoesNotJumpOnStopwords() {
        let m = matcher("Astra explique un système vraiment utile pour demain")
        send(m, "Astra explique")
        let cursor = m.cursor
        send(m, "et de la puis et de", kind: .volatile, at: 1)
        XCTAssertEqual(m.cursor, cursor)
    }

    func testResumeAfterImprovisation() {
        let m = matcher("Astra explique une méthode utile pour demain et raconte plusieurs histoires")
        send(m, "Astra explique")
        send(m, "une anecdote personnelle imprévue", kind: .volatile, at: 1)
        send(m, "une méthode utile", kind: .volatile, at: 2)
        XCTAssertTrue((3...4).contains(m.cursor), "\(m.lastDebug)")
    }

    func testRepeatingPreviousPhraseDoesNotRewind() {
        let m = matcher("Astra présente une méthode simple puis Fable décrit notre voyage")
        send(m, "Astra présente une méthode simple puis Fable")
        let cursor = m.cursor
        send(m, "Astra présente une méthode", kind: .volatile, at: 2)
        XCTAssertEqual(m.cursor, cursor)
    }

    func testParagraphJumpWithinWindow() {
        let m = matcher("Astra présente une méthode simple pour apprendre beaucoup de choses. Ensuite Fable raconte comment traverser la montagne sans perdre courage.")
        send(m, "Astra présente")
        send(m, "Ensuite Fable raconte comment", kind: .volatile, at: 1)
        XCTAssertTrue(m.cursor >= 10, "\(m.lastDebug)")
    }

    func testGlobalJumpAfterSixSeconds() {
        let filler = (0..<50).map { "paragraphe\($0)" }.joined(separator: " ")
        let m = matcher("Astra présente un projet \(filler) Fable raconte une histoire très surprenante demain")
        send(m, "Astra présente")
        send(m, "improvisation libre avec une anecdote inconnue", kind: .final, at: 1)
        send(m, "Fable raconte une histoire très surprenante demain", kind: .final, at: 7)
        XCTAssertTrue(m.cursor > 50, "\(m.lastDebug)")
    }

    func testRecognitionError() {
        let m = matcher("Astra dévoile une technologie remarquable")
        send(m, "astrat dévoile une technologie")
        XCTAssertTrue(m.cursor >= 2, "\(m.lastDebug)")
    }

    func testNearestRepeatedPhraseWins() {
        let m = matcher("Astra présente une méthode. Fable explique une chose. Astra présente une méthode. Fable finit.")
        send(m, "Astra présente une méthode")
        XCTAssertTrue(m.cursor < 5, "\(m.lastDebug)")
    }

    func testWrittenNumberCanBeSkipped() {
        let m = matcher("Cette machine coûte quatre vingt dix euros aujourd'hui")
        send(m, "Cette machine coûte 90 euros aujourd'hui")
        XCTAssertTrue(m.cursor >= 7, "\(m.lastDebug)")
    }

    func testVolatileRevisionReplacesPreviousSegment() {
        let m = matcher("Astra présente une méthode. Fable explique la suite")
        send(m, "Astra présente", kind: .volatile)
        send(m, "Fable explique", kind: .volatile, at: 1)
        XCTAssertEqual(m.lastDebug.heardTail, ["fable", "explique"])
        send(m, "Fable explique", kind: .final, at: 2)
        XCTAssertEqual(m.lastDebug.heardTail, ["fable", "explique"])
    }

    func testBackwardRequiresFourExactStrongWords() {
        let m = matcher("Astra présente méthode fiable. Fable raconte cette histoire passionnante", backward: true)
        m.reanchor(to: 5)
        send(m, "Astra présente méthode fiable")
        XCTAssertTrue(m.cursor < 5, "\(m.lastDebug)")
    }

    func testIngestPerformanceFiveThousandWords() {
        let script = (0..<5_000).map { "terme\($0)" }.joined(separator: " ")
        let m = matcher(script)
        let update = TranscriptUpdate(kind: .volatile, text: "terme100 terme101 terme102", timestamp: base)
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 { m.ingest(update) }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertLessThan(elapsed / 100, 0.002)
    }
}
