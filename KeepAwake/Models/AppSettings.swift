import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let startAtLogin = "startAtLogin"
        static let activateOnLaunch = "activateOnLaunch"
        static let deactivateBelowThreshold = "deactivateBelowThreshold"
        static let batteryThreshold = "batteryThreshold"
        static let deactivateOnLowPowerMode = "deactivateOnLowPowerMode"
        static let allowDisplaySleep = "allowDisplaySleep"
        static let allowPowerNap = "allowPowerNap"
        static let showStatusLabel = "showStatusLabel"
        static let autoActivateOnFocus = "autoActivateOnFocus"
        static let autoActivateOnScreenSharing = "autoActivateOnScreenSharing"
        static let deactivateWhenFocusEnds = "deactivateWhenFocusEnds"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasPresentedInitialSettingsWindow = "hasPresentedInitialSettingsWindow"
        static let durations = "durations"
        static let defaultDurationID = "defaultDurationID"
        static let pinnedDurationIDs = "pinnedDurationIDs"
    }

    // MARK: - Snap points for the battery slider
    /// These act as "magnetic" anchor points — the slider snaps to them
    /// when the user drags within ±magnetRadius of one. Free values are
    /// still stored and displayed between snap points.
    nonisolated static let batterySnapPoints = [10, 20, 50, 70, 90]
    nonisolated static let batteryMagnetRadius = 4  // %
    nonisolated static let batteryRange = 1...100

    /// The persistence backend. Defaults to `UserDefaults.standard`;
    /// pass an `iCloudFallbackStore()` for transparent iCloud sync.
    private let userDefaults: any SettingsStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Published var startAtLogin: Bool {
        didSet { userDefaults.set(startAtLogin, forKey: Keys.startAtLogin) }
    }

    @Published var activateOnLaunch: Bool {
        didSet { userDefaults.set(activateOnLaunch, forKey: Keys.activateOnLaunch) }
    }

    @Published var deactivateBelowThreshold: Bool {
        didSet { userDefaults.set(deactivateBelowThreshold, forKey: Keys.deactivateBelowThreshold) }
    }

    /// Battery threshold in percent (1–100). Stored as-is; UI applies
    /// magnetic snapping but any value in range is valid.
    @Published var batteryThreshold: Int {
        didSet {
            let clamped = batteryThreshold.clamped(to: AppSettings.batteryRange)
            if clamped != batteryThreshold { batteryThreshold = clamped; return }
            userDefaults.set(clamped, forKey: Keys.batteryThreshold)
        }
    }

    @Published var deactivateOnLowPowerMode: Bool {
        didSet { userDefaults.set(deactivateOnLowPowerMode, forKey: Keys.deactivateOnLowPowerMode) }
    }

    @Published var allowDisplaySleep: Bool {
        didSet { userDefaults.set(allowDisplaySleep, forKey: Keys.allowDisplaySleep) }
    }

    /// When `true`, uses `kIOPMAssertionTypePreventSystemSleep` so Power Nap
    /// (background syncs, Time Machine, push email) can still run while
    /// your session is active. When `false`, uses `PreventUserIdleSystemSleep`
    /// for stricter idle-sleep prevention.
    @Published var allowPowerNap: Bool {
        didSet { userDefaults.set(allowPowerNap, forKey: Keys.allowPowerNap) }
    }

    /// When on, a live glanceable countdown (e.g. "☕ 42m") is shown next to
    /// the icon in the menu bar while a timed session is active.
    @Published var showStatusLabel: Bool {
        didSet { userDefaults.set(showStatusLabel, forKey: Keys.showStatusLabel) }
    }

    // MARK: - Automation

    /// Automatically activate the default duration when Focus Mode turns on.
    @Published var autoActivateOnFocus: Bool {
        didSet { userDefaults.set(autoActivateOnFocus, forKey: Keys.autoActivateOnFocus) }
    }

    /// Automatically activate the default duration when Screen Sharing begins.
    @Published var autoActivateOnScreenSharing: Bool {
        didSet { userDefaults.set(autoActivateOnScreenSharing, forKey: Keys.autoActivateOnScreenSharing) }
    }

    /// Deactivate automatically when Focus Mode turns off (only if it was auto-activated by KeepAwake).
    @Published var deactivateWhenFocusEnds: Bool {
        didSet { userDefaults.set(deactivateWhenFocusEnds, forKey: Keys.deactivateWhenFocusEnds) }
    }

    /// True once the user has completed the first-run onboarding flow.
    @Published var hasCompletedOnboarding: Bool {
        didSet { userDefaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    @Published var hasPresentedInitialSettingsWindow: Bool {
        didSet { userDefaults.set(hasPresentedInitialSettingsWindow, forKey: Keys.hasPresentedInitialSettingsWindow) }
    }


    @Published private(set) var availableDurations: [ActivationDuration] {
        didSet { persistDurations() }
    }

    @Published var defaultDurationID: ActivationDuration.ID {
        didSet { userDefaults.set(defaultDurationID, forKey: Keys.defaultDurationID) }
    }

    /// IDs of durations pinned as quick-access buttons in the menu bar popover.
    /// Maximum 3 items. Always ordered by the user's chosen sequence.
    @Published var pinnedDurationIDs: [String] {
        didSet { userDefaults.set(pinnedDurationIDs, forKey: Keys.pinnedDurationIDs) }
    }

    nonisolated static let defaultPinnedIDs: [String] = [
        ActivationDuration.minutes(15).id,
        ActivationDuration.hours(1).id,
        ActivationDuration.indefinite.id,
    ]

    var defaultDuration: ActivationDuration {
        availableDurations.first(where: { $0.id == defaultDurationID }) ?? ActivationDuration.minutes(15)
    }

    var sessionOptions: SessionOptions {
        SessionOptions(
            allowDisplaySleep: allowDisplaySleep,
            allowPowerNap: allowPowerNap,
            batteryThreshold: deactivateBelowThreshold ? batteryThreshold : nil,
            stopOnLowPowerMode: deactivateOnLowPowerMode
        )
    }

    // MARK: - Init

    /// Designated initialiser.
    /// - Parameter store: The key-value store to persist settings in.
    ///   Pass `iCloudFallbackStore()` to opt in to transparent iCloud sync;
    ///   leave blank to use `UserDefaults.standard`.
    init(store: any SettingsStore = UserDefaults.standard) {
        self.userDefaults = store

        let durations = Self.loadDurations(from: store)
        let savedDefaultID = userDefaults.string(forKey: Keys.defaultDurationID) ?? ActivationDuration.minutes(15).id
        let savedPinnedIDs = userDefaults.stringArray(forKey: Keys.pinnedDurationIDs) ?? Self.defaultPinnedIDs

        self.startAtLogin = userDefaults.bool(forKey: Keys.startAtLogin)
        self.activateOnLaunch = userDefaults.bool(forKey: Keys.activateOnLaunch)
        self.deactivateBelowThreshold = userDefaults.bool(forKey: Keys.deactivateBelowThreshold)
        let rawThreshold = userDefaults.object(forKey: Keys.batteryThreshold) as? Int ?? 20
        self.batteryThreshold = rawThreshold.clamped(to: Self.batteryRange)
        self.deactivateOnLowPowerMode = userDefaults.bool(forKey: Keys.deactivateOnLowPowerMode)
        self.allowDisplaySleep = userDefaults.bool(forKey: Keys.allowDisplaySleep)
        self.allowPowerNap = userDefaults.bool(forKey: Keys.allowPowerNap)
        self.showStatusLabel = userDefaults.bool(forKey: Keys.showStatusLabel)
        self.autoActivateOnFocus = userDefaults.bool(forKey: Keys.autoActivateOnFocus)
        self.autoActivateOnScreenSharing = userDefaults.bool(forKey: Keys.autoActivateOnScreenSharing)
        self.deactivateWhenFocusEnds = userDefaults.bool(forKey: Keys.deactivateWhenFocusEnds)
        self.hasCompletedOnboarding = userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.hasPresentedInitialSettingsWindow = userDefaults.bool(forKey: Keys.hasPresentedInitialSettingsWindow)
        self.availableDurations = durations
        self.defaultDurationID = durations.contains(where: { $0.id == savedDefaultID })
            ? savedDefaultID
            : ActivationDuration.minutes(15).id
        self.pinnedDurationIDs = savedPinnedIDs.filter { id in
            durations.contains(where: { $0.id == id })
        }
        if self.pinnedDurationIDs.isEmpty {
            self.pinnedDurationIDs = Self.defaultPinnedIDs
        }
    }

    // MARK: - Duration management

    func addDuration(_ duration: ActivationDuration) {
        guard duration.totalSeconds > 0, !duration.isIndefinite else { return }
        guard !availableDurations.contains(duration) else { return }
        availableDurations.append(duration)
        availableDurations.sort(by: Self.sortDurations)
    }

    func removeDuration(id: ActivationDuration.ID) {
        guard let duration = availableDurations.first(where: { $0.id == id }) else { return }
        guard !duration.isIndefinite else { return }
        availableDurations.removeAll { $0.id == id }
        pinnedDurationIDs.removeAll { $0 == id }
        if defaultDurationID == id {
            defaultDurationID = ActivationDuration.minutes(15).id
        }
    }

    func resetDurations() {
        availableDurations = ActivationDuration.defaultDurations
        defaultDurationID = ActivationDuration.minutes(15).id
        pinnedDurationIDs = Self.defaultPinnedIDs
    }

    func setDefaultDuration(_ id: ActivationDuration.ID) {
        guard availableDurations.contains(where: { $0.id == id }) else { return }
        defaultDurationID = id
    }

    // MARK: - Pinned duration management

    func isPinned(_ id: String) -> Bool {
        pinnedDurationIDs.contains(id)
    }

    /// Pin a duration as a quick-access button. Max 3 pins — if already at max,
    /// the oldest pin is removed to make room.
    func pin(_ id: String) {
        guard availableDurations.contains(where: { $0.id == id }) else { return }
        guard !pinnedDurationIDs.contains(id) else { return }
        if pinnedDurationIDs.count >= 3 {
            pinnedDurationIDs.removeFirst()
        }
        pinnedDurationIDs.append(id)
    }

    func unpin(_ id: String) {
        pinnedDurationIDs.removeAll { $0 == id }
    }

    func togglePin(_ id: String) {
        isPinned(id) ? unpin(id) : pin(id)
    }

    // MARK: - Magnetic snap helper

    /// Returns the snap-point value if `value` is within the magnetic radius
    /// of one, otherwise returns `value` unchanged.
    nonisolated static func applyMagneticSnap(_ value: Int) -> Int {
        for snap in batterySnapPoints {
            if abs(snap - value) <= batteryMagnetRadius {
                return snap
            }
        }
        return value.clamped(to: batteryRange)
    }

    // MARK: - Private persistence

    private func persistDurations() {
        guard let data = try? encoder.encode(availableDurations) else { return }
        userDefaults.set(data, forKey: Keys.durations)
    }

    private static func loadDurations(from store: any SettingsStore) -> [ActivationDuration] {
        guard let data = store.object(forKey: Keys.durations) as? Data,
              let durations = try? JSONDecoder().decode([ActivationDuration].self, from: data),
              !durations.isEmpty else {
            return ActivationDuration.defaultDurations
        }
        return durations.sorted(by: sortDurations)
    }

    private static func sortDurations(lhs: ActivationDuration, rhs: ActivationDuration) -> Bool {
        switch (lhs.isIndefinite, rhs.isIndefinite) {
        case (true, _): return false
        case (_, true): return true
        case (false, false): return lhs.totalSeconds < rhs.totalSeconds
        }
    }
}

// MARK: - Comparable extension

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}
