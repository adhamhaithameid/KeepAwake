import XCTest

final class KeepAwakeUITests: XCTestCase {
    func test_app_launches() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
