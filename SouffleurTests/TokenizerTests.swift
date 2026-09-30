import XCTest
@testable import Souffleur

final class TokenizerTests: XCTestCase {
    func testElisionsAndTypographicApostrophes() {
        let text = "l'impression qu’on dʼaccord aujourd'hui"
        let tokens = Tokenizer.tokenize(text)
        XCTAssertEqual(tokens.map(\.key), ["l", "impression", "qu", "on", "d", "accord", "aujourdhui"])
        let source = text as NSString
        XCTAssertEqual(tokens.map { source.substring(with: $0.range) }, ["l", "impression", "qu", "on", "d", "accord", "aujourd'hui"])
    }

    func testDiacriticsHyphensAndSymbols() {
        XCTAssertEqual(Tokenizer.tokenize("Été peut-être 90 € 20 % &").map(\.key),
                       ["ete", "peut", "etre", "90", "euros", "20", "pourcent", "et"])
    }

    func testStemsAndWeights() {
        let words = Tokenizer.tokenize("parlent parles parle chats le de the astrat")
        XCTAssertEqual(words.prefix(3).map(\.stem), ["parl", "parl", "parl"])
        XCTAssertEqual(words[3].stem, "chat")
        XCTAssertEqual(words[4].weight, 0.3)
        XCTAssertEqual(words[5].weight, 0.3)
        XCTAssertEqual(words[6].weight, 0.3)
        XCTAssertEqual(words[7].weight, 1)
    }

    func testUTF16Ranges() {
        let text = "🎙️ Astra l’idée"
        let source = text as NSString
        let tokens = Tokenizer.tokenize(text)
        XCTAssertEqual(tokens.map { source.substring(with: $0.range) }, ["Astra", "l", "idée"])
        XCTAssertEqual(tokens[0].range.location, ("🎙️ " as NSString).length)
    }
}
