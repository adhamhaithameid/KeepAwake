import XCTest

final class KeepAwakeUITests: XCTestCase {
    @MainActor
    func test_app_launches() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
