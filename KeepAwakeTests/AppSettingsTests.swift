import XCTest
@testable import KeepAwake

@MainActor
final class AppSettingsTests: XCTestCase {
    func test_default_duration_starts_at_fifteen_minutes() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertEqual(settings.defaultDuration, .minutes(15))
    }

    func test_custom_duration_can_be_added_and_selected_as_default() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let settings = AppSettings(userDefaults: defaults)
        let custom = ActivationDuration(hours: 0, minutes: 45, seconds: 0)

        settings.addDuration(custom)
        settings.setDefaultDuration(custom.id)

        XCTAssertTrue(settings.availableDurations.contains(custom))
        XCTAssertEqual(settings.defaultDurationID, custom.id)
    }
}
