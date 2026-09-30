import XCTest
@testable import Souffleur

final class SmokeTests: XCTestCase {
    func testDefaultsRegistered() {
        SettingsKeys.register()
        XCTAssertEqual(SettingsKeys.currentAppearance().fontSize, 32)
    }
}
