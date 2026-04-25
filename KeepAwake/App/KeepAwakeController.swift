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
    /// Set when an IOKit power assertion fails to be created (SE-7).
    /// Displayed as a transient error banner in the menu header.
    @Published var lastAssertionError: String? = nil

    /// Called when the user requests to re-show the welcome/onboarding guide (UX-7).
    /// Wired up in AppEnvironment to `OnboardingWindowManager.show`.
    var onShowWelcomeGuide: (() -> Void)?
    /// Called when a timed session expires (UX-5 — triggers icon flash).
    var onSessionExpired: (() -> Void)?

    private let sessionController: ActivationSessionManaging
    private let windowManager: SettingsWindowManaging
    private let launchAtLoginManager: LaunchAtLoginManaging
    private let linkOpener: LinkOpening
    private let notifications: NotificationManager
    private let focusService: FocusDetectionService
    private var cancellables: Set<AnyCancellable> = []
    private var lastHandledStopReason: StopReason?
    /// True when the session was auto-started by a Focus Mode trigger.
    private var sessionStartedByFocus = false

    init(
        settings: AppSettings,
        sessionController: ActivationSessionManaging,
        windowManager: SettingsWindowManaging,
        launchAtLoginManager: LaunchAtLoginManaging,
        linkOpener: LinkOpening,
        notifications: NotificationManager = .shared,
        focusService: FocusDetectionService
    ) {
        self.settings = settings
        self.sessionController = sessionController
        self.windowManager = windowManager
        self.launchAtLoginManager = launchAtLoginManager
        self.linkOpener = linkOpener
        self.notifications = notifications
        self.focusService = focusService
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

        // Wire the "Extend +30m" notification action.
        notifications.onExtendRequested = { [weak self] in
            Task { await self?.extendSession(by: 30 * 60) }
        }

        setupFocusDetection()
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
        focusService.start()

        if settings.startAtLogin != launchAtLoginManager.isEnabled {
            launchAtLoginManager.isEnabled = settings.startAtLogin
            objectWillChange.send()
        }

        guard settings.activateOnLaunch else { return }
        await activate(duration: settings.defaultDuration)
    }

    func handleTermination() async {
        focusService.stop()
        guard isActive else { return }
        await sessionController.stop(reason: .appTermination)
        statusMessage = "Stopped"
        objectWillChange.send()
    }

    /// Synchronous teardown for use **only** from `applicationWillTerminate`.
    ///
    /// AppKit calls `applicationWillTerminate` on the main thread while the run
    /// loop is blocked, so `await` and `DispatchSemaphore.wait()` both deadlock.
    /// This method cancels all async tasks (non-blocking) and calls
    /// `IOPMAssertionRelease` synchronously — which is all that’s actually needed
    /// to release the power assertion before the process exits.
    func terminateSync() {
        focusService.stop()
        sessionController.deactivateSync()
        statusMessage = "Stopped"
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
        lastAssertionError = nil
        await sessionController.start(duration: duration, options: settings.sessionOptions)
        // SE-7: If the session didn't actually start (IOKit assertion failed),
        // surface a brief error message so the user knows why.
        if !isActive {
            lastAssertionError = "Could not create power assertion. Check System Preferences → Energy Saver."
            statusMessage = "Failed to start session"
            // Auto-clear the error banner after 6 seconds.
            Task {
                try? await Task.sleep(for: .seconds(6))
                if self.lastAssertionError != nil { self.lastAssertionError = nil }
            }
        } else {
            statusMessage = duration.isIndefinite ? "Active indefinitely" : "Active for \(duration.menuTitle)"
        }
        objectWillChange.send()
    }

    /// Manually stop the active session.
    func stopActiveSession() async {
        sessionStartedByFocus = false
        await sessionController.stop(reason: .manual)
        statusMessage = "Stopped"
        objectWillChange.send()
    }

    /// Extend the current session by `seconds` seconds.
    func extendSession(by extraSeconds: TimeInterval) async {
        guard let current = activeSession else { return }
        let remaining = current.endsAt.map { max($0.timeIntervalSinceNow, 0) } ?? 0
        let total = Int(remaining + extraSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        let extendedDuration = ActivationDuration(
            id: current.duration.id,
            hours: h,
            minutes: m,
            seconds: s
        )
        await activate(duration: extendedDuration)
    }

    func openSettings(selectedTab: AppTab = .settings) {
        self.selectedTab = selectedTab
        windowManager.show(selectedTab: selectedTab)
    }

    func open(_ link: ExternalLink) {
        linkOpener.open(link.url)
    }

    /// Re-shows the onboarding welcome guide (UX-7).
    /// Resets the completion flag so the window will reappear.
    func showWelcomeGuide() {
        settings.hasCompletedOnboarding = false
        onShowWelcomeGuide?()
    }

    // MARK: - Focus Detection

    private func setupFocusDetection() {
        focusService.onFocusEnabled = { [weak self] in
            guard let self, self.settings.autoActivateOnFocus, !self.isActive else { return }
            self.sessionStartedByFocus = true
            Task { await self.activate(duration: self.settings.defaultDuration) }
        }

        focusService.onFocusDisabled = { [weak self] in
            guard let self,
                  self.settings.autoActivateOnFocus,
                  self.settings.deactivateWhenFocusEnds,
                  self.isActive,
                  self.sessionStartedByFocus else { return }
            self.sessionStartedByFocus = false
            Task { await self.stopActiveSession() }
        }

        focusService.onScreenSharingStarted = { [weak self] in
            guard let self, self.settings.autoActivateOnScreenSharing, !self.isActive else { return }
            Task { await self.activate(duration: self.settings.defaultDuration) }
        }

        // Screen sharing stop doesn't auto-deactivate (screen sharing ends happen
        // more unexpectedly than Focus mode, so we leave it running).
    }

    // MARK: - Helpers

    private func timeLabel(seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }

    private func handleSessionChange(_ obs: ActivationSessionController) {
        guard obs.activeSession == nil else { return }
        let reason = obs.lastStopReason
        guard reason != nil,
              reason != lastHandledStopReason,
              reason != .manual,
              reason != .appTermination,
              reason != .replaced else { return }
        lastHandledStopReason = reason
        // Clear the selected-duration highlight so the Durations tab doesn't
        // show a stale active ring after an auto-stop (SE-6).
        selectedDurationID = nil
        if let autoReason = reason {
            notifications.notifyAutoStop(reason: autoReason)
            switch autoReason {
            case .lowPowerMode:
                statusMessage = "Stopped — Low Power Mode active"
            case .batteryThreshold:
                statusMessage = "Stopped — battery below threshold"
            case .expired:
                statusMessage = "Session ended"
                // UX-5: Notify listener (StatusItemController) to flash the icon.
                onSessionExpired?()
            default: break
            }
            objectWillChange.send()
        }
    }
}
