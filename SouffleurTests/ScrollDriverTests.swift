import XCTest
@testable import Souffleur

final class ScrollDriverTests: XCTestCase {
    func testConstantDistanceAndVoice() {
        var driver = ScrollDriver(mode: .constant, speed: 40, thresholdDb: -45)
        XCTAssertEqual(driver.step(dt: 0.25, levelDb: -100), 10)
        driver.mode = .voice
        XCTAssertEqual(driver.step(dt: 1, levelDb: 0), 0)
    }

    func testSoundAttackAndHold() {
        var driver = ScrollDriver(mode: .sound, speed: 100, thresholdDb: -45)
        XCTAssertEqual(driver.step(dt: 0.04, levelDb: -30), 0)
        XCTAssertEqual(driver.step(dt: 0.04, levelDb: -30), 0)
        XCTAssertEqual(driver.step(dt: 0.1, levelDb: -30), 10, accuracy: 0.001)
        XCTAssertEqual(driver.step(dt: 0.2, levelDb: -60), 20, accuracy: 0.001)
        XCTAssertEqual(driver.step(dt: 0.3, levelDb: -60), 20, accuracy: 0.001)
        XCTAssertEqual(driver.step(dt: 0.1, levelDb: -60), 0)
        XCTAssertEqual(driver.step(dt: -1, levelDb: 0), 0)
    }
}
