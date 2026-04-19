import XCTest
@testable import KeepAwake

final class ActivationDurationTests: XCTestCase {
    func test_default_durations_start_with_fifteen_minutes() {
        XCTAssertEqual(ActivationDuration.defaultDurations.first, .minutes(15))
    }

    func test_indefinite_duration_has_expected_title() {
        XCTAssertTrue(ActivationDuration.indefinite.isIndefinite)
        XCTAssertEqual(ActivationDuration.indefinite.menuTitle, "Indefinitely")
    }
}
