import XCTest
@testable import Souffleur

final class VocabularyExtractorTests: XCTestCase {
    func testRareWordsAndDeduplication() {
        let words = VocabularyExtractor.contextualWords(in: "Astra et Fable. Astra parle avec Zéphyr; Fable répond.")
        XCTAssertEqual(words.filter { $0 == "Astra" }.count, 1)
        XCTAssertTrue(words.contains("Fable"))
        XCTAssertTrue(words.contains("Zéphyr"))
        XCTAssertFalse(words.contains("avec"))
    }

    func testLimit() {
        XCTAssertEqual(VocabularyExtractor.contextualWords(in: "Astra Fable Zéphyr", limit: 2).count, 2)
        XCTAssertEqual(VocabularyExtractor.contextualWords(in: "Astra", limit: 0), [])
    }
}
