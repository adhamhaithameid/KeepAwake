import Foundation

@MainActor
final class KeepAwakeAppEnvironment {
    let controller: KeepAwakeController
    let settingsWindowManager: SettingsWindowManager
    let statusItemController: StatusItemController

    init(
        controller: KeepAwakeController,
        settingsWindowManager: SettingsWindowManager,
        statusItemController: StatusItemController
    ) {
        self.controller = controller
        self.settingsWindowManager = settingsWindowManager
        self.statusItemController = statusItemController
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
        let bridgeWindowManager = BridgeSettingsWindowManager()
        let controller = KeepAwakeController(
            settings: settings,
            sessionController: sessionController,
            windowManager: bridgeWindowManager,
            launchAtLoginManager: LiveLaunchAtLoginManager(),
            linkOpener: WorkspaceLinkOpener()
        )
        let settingsWindowManager = SettingsWindowManager {
            SettingsWindowView(controller: controller)
        }
        bridgeWindowManager.base = settingsWindowManager
        let statusItemController = StatusItemController(controller: controller)

        return KeepAwakeAppEnvironment(
            controller: controller,
            settingsWindowManager: settingsWindowManager,
            statusItemController: statusItemController
        )
    }
}

@MainActor
private final class BridgeSettingsWindowManager: SettingsWindowManaging {
    var base: SettingsWindowManaging?

    func show(selectedTab: AppTab) {
        base?.show(selectedTab: selectedTab)
    }
}
