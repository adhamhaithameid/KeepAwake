import Combine
import Foundation
import IOKit.ps

@MainActor
final class KeepAwakeController: ObservableObject {
    let settings: AppSettings

    @Published var selectedTab: AppTab = .settings
    @Published var selectedDurationID: ActivationDuration.ID?
    @Published var isShowingAddDurationSheet = false
    @Published var statusMessage = "Ready"

    private let sessionController: ActivationSessionManaging
    private let windowManager: SettingsWindowManaging
    private let launchAtLoginManager: LaunchAtLoginManaging
    private let linkOpener: LinkOpening
    private let notifications: NotificationManager
    private var cancellables: Set<AnyCancellable> = []
    /// Tracks the reason of the previous stop to fire notifications only once.
    private var lastHandledStopReason: StopReason?

    init(
        settings: AppSettings,
        sessionController: ActivationSessionManaging,
        windowManager: SettingsWindowManaging,
        launchAtLoginManager: LaunchAtLoginManaging,
        linkOpener: LinkOpening,
        notifications: NotificationManager = .shared
    ) {
        self.settings = settings
        self.sessionController = sessionController
        self.windowManager = windowManager
        self.launchAtLoginManager = launchAtLoginManager
        self.linkOpener = linkOpener
        self.notifications = notifications
        self.selectedDurationID = settings.defaultDurationID

        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        if let obs = sessionController as? ActivationSessionController {
            obs.objectWillChange
                .sink { [weak self] _ in
                    self?.handleSessionChange(obs)
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Computed properties

    var isActive: Bool { sessionController.activeSession != nil }
    var activeSession: ActivationSession? { sessionController.activeSession }

    var statusIconName: String {
        isActive ? "MenuBarCoffeeFilled" : "MenuBarCoffeeOutline"
    }

    var startAtLoginEnabled: Bool {
        get { launchAtLoginManager.isEnabled }
        set {
            launchAtLoginManager.isEnabled = newValue
            settings.startAtLogin = newValue
            objectWillChange.send()
        }
    }

    /// Current device battery level (nil when on AC with no battery info).
    /// Reads live from IOKit — cheap enough for periodic UI polling.
    var currentBatteryLevel: Int? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as Array
        let desc = list.first.flatMap {
            IOPSGetPowerSourceDescription(info, $0).takeUnretainedValue() as? [String: Any]
        }
        return desc?[kIOPSCurrentCapacityKey as String] as? Int
    }

    // MARK: - Lifecycle

    func handleLaunch() async {
        notifications.requestPermissionIfNeeded()

        if settings.startAtLogin != launchAtLoginManager.isEnabled {
            launchAtLoginManager.isEnabled = settings.startAtLogin
            objectWillChange.send()
        }

        if !settings.hasPresentedInitialSettingsWindow {
            settings.hasPresentedInitialSettingsWindow = true
            openSettings(selectedTab: .settings)
        }

        guard settings.activateOnLaunch else { return }
        await activate(duration: settings.defaultDuration)
    }

    func handleTermination() async {
        guard isActive else { return }
        await sessionController.stop(reason: .appTermination)
        statusMessage = "Stopped"
        objectWillChange.send()
    }

    func handlePrimaryClick() async {
        if isActive {
            await stopActiveSession()
        } else {
            await activate(duration: settings.defaultDuration)
        }
    }

    /// Activates the default duration instantly — used by ⌥ click.
    func activateDefault() async {
        await activate(duration: settings.defaultDuration)
    }

    func activate(duration: ActivationDuration) async {
        selectedDurationID = duration.id
        lastHandledStopReason = nil
        await sessionController.start(duration: duration, options: settings.sessionOptions)
        statusMessage = duration.isIndefinite ? "Active indefinitely" : "Active for \(duration.menuTitle)"
        objectWillChange.send()
    }

    /// Manually stop the active session.
    func stopActiveSession() async {
        await sessionController.stop(reason: .manual)
        statusMessage = "Stopped"
        objectWillChange.send()
    }

    func openSettings(selectedTab: AppTab = .settings) {
        self.selectedTab = selectedTab
        windowManager.show(selectedTab: selectedTab)
    }

    func open(_ link: ExternalLink) {
        linkOpener.open(link.url)
    }

    // MARK: - Private

    /// Called every time the session controller publishes a change.
    /// Fires a notification when an auto-stop is detected.
    private func handleSessionChange(_ obs: ActivationSessionController) {
        guard obs.activeSession == nil else { return }  // Session is still running

        let reason = obs.lastStopReason
        guard reason != nil,
              reason != lastHandledStopReason,
              reason != .manual,
              reason != .appTermination,
              reason != .replaced else { return }

        lastHandledStopReason = reason
        if let autoReason = reason {
            notifications.notifyAutoStop(reason: autoReason)
            switch autoReason {
            case .lowPowerMode:
                statusMessage = "Stopped — Low Power Mode active"
            case .batteryThreshold:
                statusMessage = "Stopped — battery below threshold"
            case .expired:
                statusMessage = "Session ended"
            default:
                break
            }
            objectWillChange.send()
        }
    }
}
