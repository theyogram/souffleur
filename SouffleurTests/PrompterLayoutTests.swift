import AppKit
import XCTest
@testable import Souffleur

@MainActor
final class PrompterLayoutTests: XCTestCase {
    func testWordMovesToNewLineAfterWidthAndFontChanges() {
        let text = "Bonjour ceci est une phrase assez longue pour forcer le retour à la ligne dans une fenêtre étroite."
        let tokens = makeTokens(text)
        let view = PrompterTextView()
        view.isHorizontallyResizable = false
        view.textContainer?.widthTracksTextView = true
        view.frame = NSRect(x: 0, y: 0, width: 500, height: 700)
        var appearance = PrompterAppearance()
        view.configure(text: text, tokens: tokens, appearance: appearance, spokenIndex: -1)
        let wide = view.lineRect(for: 8)
        XCTAssertNotNil(wide)
        view.frame.size.width = 210
        let narrow = view.lineRect(for: 8)
        XCTAssertNotNil(narrow)
        XCTAssertGreaterThan(narrow?.minY ?? 0, wide?.minY ?? 0)
        appearance.fontSize = 48
        view.updateAppearance(appearance)
        let large = view.lineRect(for: 8)
        XCTAssertNotNil(large)
        XCTAssertGreaterThanOrEqual(large?.minY ?? 0, narrow?.minY ?? 0)
    }

    func testTargetIsBounded() {
        XCTAssertEqual(PrompterLayout.targetY(lineY: 0, visibleHeight: 300, contentHeight: 1000, readingLine: 0.2), 0)
        XCTAssertEqual(PrompterLayout.targetY(lineY: 1000, visibleHeight: 300, contentHeight: 1000, readingLine: 0.2), 700)
        XCTAssertEqual(PrompterLayout.targetY(lineY: 500, visibleHeight: 300, contentHeight: 200, readingLine: 0.2), 0)
    }

    func testReadingLineReturnsFirstWordOfLine() {
        let text = "Un deux trois quatre cinq six sept huit neuf dix onze douze treize quatorze quinze seize dixsept dixhuit."
        let tokens = makeTokens(text)
        let view = PrompterTextView()
        view.isHorizontallyResizable = false
        view.textContainer?.widthTracksTextView = true
        view.frame = NSRect(x: 0, y: 0, width: 240, height: 700)
        view.configure(text: text, tokens: tokens, appearance: PrompterAppearance(), spokenIndex: -1)
        guard let line = view.lineRect(for: 8) else { XCTFail("Ligne absente"); return }
        let first = view.firstWordIndex(onLineAt: line.minY)
        XCTAssertLessThanOrEqual(first, 8)
        XCTAssertEqual(view.lineRect(for: first)?.minY, line.minY)
        if first > 0 { XCTAssertNotEqual(view.lineRect(for: first - 1)?.minY, line.minY) }
    }

    func testContinuousPositionGrowsWithEachWordAndReachesNextLine() {
        let text = "Un deux trois quatre cinq six sept huit neuf dix onze douze treize quatorze quinze seize dixsept dixhuit."
        let tokens = makeTokens(text)
        let view = PrompterTextView()
        view.isHorizontallyResizable = false
        view.textContainer?.widthTracksTextView = true
        view.frame = NSRect(x: 0, y: 0, width: 240, height: 700)
        view.configure(text: text, tokens: tokens, appearance: PrompterAppearance(), spokenIndex: -1)
        var previous: CGFloat = -1
        for index in tokens.indices {
            guard let y = view.continuousY(for: index) else { XCTFail("Position absente"); return }
            XCTAssertGreaterThan(y, previous)
            previous = y
        }
        guard let firstLine = view.lineRect(for: 0) else { XCTFail("Ligne absente"); return }
        let next = view.firstWordIndex(onLineAt: firstLine.maxY)
        XCTAssertGreaterThan(next, 0)
        XCTAssertEqual(view.continuousY(for: next - 1) ?? 0, firstLine.maxY, accuracy: 0.5)
    }

    func testControllerReadingLineIndexFollowsScrolledText() {
        let text = Array(repeating: "La caméra attend une phrase claire et le prompteur suit les mots prononcés.", count: 20).joined(separator: "\n")
        let tokens = makeTokens(text)
        let controller = PrompterWindowController()
        controller.setScript(text: text, tokens: tokens)
        let initialIndex = controller.wordIndexAtReadingLine
        XCTAssertGreaterThanOrEqual(initialIndex, 0)
        controller.setCursor(wordIndex: tokens.count - 1, animated: false)
        XCTAssertGreaterThan(controller.wordIndexAtReadingLine, initialIndex)
        XCTAssertLessThanOrEqual(controller.wordIndexAtReadingLine, tokens.count - 1)
    }

    private func makeTokens(_ text: String) -> [ScriptToken] {
        let regex = try! NSRegularExpression(pattern: #"[\p{L}]+"#)
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map { match in
            let display = (text as NSString).substring(with: match.range)
            return ScriptToken(display: display, key: display.lowercased(), stem: display.lowercased(), range: match.range, weight: 1)
        }
    }
}
