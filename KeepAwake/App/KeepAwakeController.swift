import Combine
import Foundation

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
    private var cancellables: Set<AnyCancellable> = []

    init(
        settings: AppSettings,
        sessionController: ActivationSessionManaging,
        windowManager: SettingsWindowManaging,
        launchAtLoginManager: LaunchAtLoginManaging,
        linkOpener: LinkOpening
    ) {
        self.settings = settings
        self.sessionController = sessionController
        self.windowManager = windowManager
        self.launchAtLoginManager = launchAtLoginManager
        self.linkOpener = linkOpener
        self.selectedDurationID = settings.defaultDurationID

        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        if let observableSessionController = sessionController as? ActivationSessionController {
            observableSessionController.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    var isActive: Bool {
        sessionController.activeSession != nil
    }

    var activeSession: ActivationSession? {
        sessionController.activeSession
    }

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

    func handleLaunch() async {
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
        objectWillChange.send()
        if isActive {
            await sessionController.stop(reason: .manual)
            statusMessage = "Stopped"
        } else {
            await activate(duration: settings.defaultDuration)
        }
        objectWillChange.send()
    }

    func activate(duration: ActivationDuration) async {
        selectedDurationID = duration.id
        await sessionController.start(duration: duration, options: settings.sessionOptions)
        statusMessage = duration.isIndefinite ? "Active indefinitely" : "Active for \(duration.menuTitle)"
        objectWillChange.send()
    }

    func openSettings(selectedTab: AppTab = .settings) {
        self.selectedTab = selectedTab
        windowManager.show(selectedTab: selectedTab)
    }

    func open(_ link: ExternalLink) {
        linkOpener.open(link.url)
    }
}
