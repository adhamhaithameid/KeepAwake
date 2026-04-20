import Foundation

@MainActor
final class KeepAwakeAppEnvironment {
    let controller: KeepAwakeController
    let settingsWindowManager: SettingsWindowManager
    let statusItemController: StatusItemController
    let onboardingManager: OnboardingWindowManager

    init(
        controller: KeepAwakeController,
        settingsWindowManager: SettingsWindowManager,
        statusItemController: StatusItemController,
        onboardingManager: OnboardingWindowManager
    ) {
        self.controller = controller
        self.settingsWindowManager = settingsWindowManager
        self.statusItemController = statusItemController
        self.onboardingManager = onboardingManager
    }
}

enum AppEnvironment {
    @MainActor
    static func makeEnvironment() -> KeepAwakeAppEnvironment {
        let settings = AppSettings()
        let sessionController = ActivationSessionController(
            assertions: LiveWakeAssertionController(),
            powerStatusProvider: LivePowerStatusProvider()
        )
        let focusService = FocusDetectionService()
        let bridgeWindowManager = BridgeSettingsWindowManager()
        let controller = KeepAwakeController(
            settings: settings,
            sessionController: sessionController,
            windowManager: bridgeWindowManager,
            launchAtLoginManager: LiveLaunchAtLoginManager(),
            linkOpener: WorkspaceLinkOpener(),
            focusService: focusService
        )
        let settingsWindowManager = SettingsWindowManager {
            SettingsWindowView(controller: controller)
        }
        bridgeWindowManager.base = settingsWindowManager
        let statusItemController = StatusItemController(controller: controller)
        let onboardingManager = OnboardingWindowManager()

        return KeepAwakeAppEnvironment(
            controller: controller,
            settingsWindowManager: settingsWindowManager,
            statusItemController: statusItemController,
            onboardingManager: onboardingManager
        )
    }
}

@MainActor
private final class BridgeSettingsWindowManager: SettingsWindowManaging {
    var base: SettingsWindowManaging?
    func show(selectedTab: AppTab) { base?.show(selectedTab: selectedTab) }
}
