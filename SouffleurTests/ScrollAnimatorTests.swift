import XCTest
@testable import Souffleur

@MainActor
final class ScrollAnimatorTests: XCTestCase {
    /// Lecture régulière : la cible avance d'un mot toutes les 300 ms.
    private func simulate(wordStep: CGFloat, every interval: Double, seconds: Double) -> (moves: [CGFloat], animator: ScrollAnimator) {
        let animator = ScrollAnimator()
        var now = 100.0
        animator.clock = { now }
        animator.snap(to: 0)
        let frame = 1.0 / 60
        var nextWord = interval
        var moves: [CGFloat] = []
        var elapsed = 0.0
        while elapsed < seconds {
            elapsed += frame
            now += frame
            if elapsed >= nextWord {
                animator.target += wordStep
                nextWord += interval
            }
            let before = animator.position
            animator.advance(by: frame, now: now)
            moves.append(animator.position - before)
        }
        return (moves, animator)
    }

    func testSteadyReadingScrollsWithoutStalling() {
        let result = simulate(wordStep: 8, every: 0.3, seconds: 8)
        let steady = result.moves.suffix(240)   // 4 dernières secondes
        let smallest = steady.min() ?? 0
        let largest = steady.max() ?? 0
        XCTAssertGreaterThan(smallest, 0, "le défilement ne doit jamais s'arrêter entre deux mots")
        XCTAssertLessThan(largest / smallest, 1.6, "la vitesse doit rester presque constante")
        XCTAssertLessThan(result.animator.target - result.animator.position, 12, "le retard reste inférieur à un mot et demi")
    }

    func testNeverOvershootsTarget() {
        let result = simulate(wordStep: 8, every: 0.3, seconds: 4)
        XCTAssertLessThanOrEqual(result.animator.position, result.animator.target)
    }

    func testStopsAtTargetWhenReaderPauses() {
        let animator = ScrollAnimator()
        var now = 0.0
        animator.clock = { now }
        animator.snap(to: 0)
        for _ in 0..<5 { now += 0.3; animator.target += 8 }
        for _ in 0..<300 { now += 1.0 / 60; animator.advance(by: 1.0 / 60, now: now) }
        XCTAssertEqual(animator.position, animator.target, accuracy: 0.1)
    }

    func testLargeJumpBackIsFast() {
        let animator = ScrollAnimator()
        var now = 0.0
        animator.clock = { now }
        animator.snap(to: 2_000)
        animator.target = 0
        for _ in 0..<60 { now += 1.0 / 60; animator.advance(by: 1.0 / 60, now: now) }
        XCTAssertLessThan(animator.position, 20)
    }
}
