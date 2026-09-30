import XCTest
@testable import Souffleur

final class AudioDevicesTests: XCTestCase {
    func testInputListContainsDefaultDevice() {
        let devices = AudioDevices.inputDevices()
        XCTAssertFalse(devices.isEmpty)
        XCTAssertTrue(devices.contains(where: \.isDefault))
        XCTAssertEqual(Set(devices.map(\.id)).count, devices.count)
    }
}
