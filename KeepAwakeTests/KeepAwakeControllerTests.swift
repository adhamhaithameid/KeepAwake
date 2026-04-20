import XCTest
@testable import KeepAwake

@MainActor
final class KeepAwakeControllerTests: XCTestCase {
    func test_default_tab_is_settings() {
        let controller = makeController()

        XCTAssertEqual(controller.selectedTab, .settings)
    }

    func test_app_bundle_is_configured_as_menu_bar_utility() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool, true)
    }

    func test_primary_click_starts_and_stops_the_default_duration() async {
        let sessionController = SessionControllerSpy()
        let controller = makeController(sessionController: sessionController)

        await controller.handlePrimaryClick()
        await controller.handlePrimaryClick()

        XCTAssertEqual(sessionController.startedDurations, [.minutes(15)])
        XCTAssertEqual(sessionController.stopCalls, 1)
    }

    func test_quick_activation_does_not_change_saved_default_duration() async {
        let sessionController = SessionControllerSpy()
        let controller = makeController(sessionController: sessionController)

        await controller.activate(duration: .hours(2))

        XCTAssertEqual(controller.settings.defaultDuration, .minutes(15))
        XCTAssertEqual(sessionController.startedDurations, [.hours(2)])
    }

    func test_launch_activates_default_duration_when_enabled() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let settings = AppSettings(userDefaults: defaults)
        settings.activateOnLaunch = true

        let sessionController = SessionControllerSpy()
        let controller = KeepAwakeController(
            settings: settings,
            sessionController: sessionController,
            windowManager: WindowManagerSpy(),
            launchAtLoginManager: LaunchAtLoginManagerSpy(),
            linkOpener: NoOpLinkOpener()
        )

        await controller.handleLaunch()

        XCTAssertEqual(sessionController.startedDurations, [.minutes(15)])
    }

    func test_first_launch_opens_settings_window() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let settings = AppSettings(userDefaults: defaults)
        let windowManager = WindowManagerSpy()

        let controller = KeepAwakeController(
            settings: settings,
            sessionController: SessionControllerSpy(),
            windowManager: windowManager,
            launchAtLoginManager: LaunchAtLoginManagerSpy(),
            linkOpener: NoOpLinkOpener()
        )

        await controller.handleLaunch()

        XCTAssertEqual(windowManager.openCalls, 1)
        XCTAssertEqual(windowManager.selectedTabs, [.settings])
    }

    private func makeController(
        sessionController: SessionControllerSpy = SessionControllerSpy()
    ) -> KeepAwakeController {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(userDefaults: defaults)
        let windowManager = WindowManagerSpy()
        let loginManager = LaunchAtLoginManagerSpy()

        return KeepAwakeController(
            settings: settings,
            sessionController: sessionController,
            windowManager: windowManager,
            launchAtLoginManager: loginManager,
            linkOpener: NoOpLinkOpener()
        )
    }
}

private final class SessionControllerSpy: ActivationSessionManaging {
    var activeSession: ActivationSession?
    var lastStopReason: StopReason?
    var startedDurations: [ActivationDuration] = []
    var stopCalls = 0

    func start(duration: ActivationDuration, options: SessionOptions) async {
        startedDurations.append(duration)
        activeSession = ActivationSession(duration: duration, startedAt: .now, endsAt: nil, options: options)
    }

    func stop(reason: StopReason) async {
        stopCalls += 1
        lastStopReason = reason
        activeSession = nil
    }
}

private final class WindowManagerSpy: SettingsWindowManaging {
    var openCalls = 0
    var selectedTabs: [AppTab] = []

    func show(selectedTab: AppTab) {
        openCalls += 1
        selectedTabs.append(selectedTab)
    }
}

private final class LaunchAtLoginManagerSpy: LaunchAtLoginManaging {
    var isEnabled = false
}
