import Foundation
import XCTest
@testable import Souffleur

final class FixtureReplayTests: XCTestCase {
    private struct Fixture: Decodable {
        var script: String
        var events: [Event]
    }
    private struct Event: Decodable {
        var time: Double
        var kind: TranscriptUpdate.Kind
        var text: String
        var expected: Int?
    }

    func testFrenchFixtureReplays() throws {
        for name in ["normal_reprise", "saut_paragraphe", "repetition_global"] {
            let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
            let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
            XCTAssertGreaterThan(Tokenizer.tokenize(fixture.script).count, 140)
            let matcher = ScriptMatcher(tokens: Tokenizer.tokenize(fixture.script))
            for event in fixture.events {
                matcher.ingest(TranscriptUpdate(kind: event.kind, text: event.text,
                                                timestamp: Date(timeIntervalSince1970: 1_000 + event.time)))
                if let expected = event.expected {
                    XCTAssertLessThanOrEqual(abs(matcher.cursor - expected), 3,
                                             "\(name) at \(event.time): \(matcher.lastDebug)")
                }
            }
        }
    }
}
