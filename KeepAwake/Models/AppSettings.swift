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
        static let durations = "durations"
        static let defaultDurationID = "defaultDurationID"
    }

    nonisolated static let thresholdStops = [10, 20, 50, 70, 90]

    private let userDefaults: UserDefaults
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

    @Published var batteryThreshold: Int {
        didSet {
            let snapped = Self.snapThreshold(batteryThreshold)
            if snapped != batteryThreshold {
                batteryThreshold = snapped
                return
            }
            userDefaults.set(snapped, forKey: Keys.batteryThreshold)
        }
    }

    @Published var deactivateOnLowPowerMode: Bool {
        didSet { userDefaults.set(deactivateOnLowPowerMode, forKey: Keys.deactivateOnLowPowerMode) }
    }

    @Published var allowDisplaySleep: Bool {
        didSet { userDefaults.set(allowDisplaySleep, forKey: Keys.allowDisplaySleep) }
    }

    @Published private(set) var availableDurations: [ActivationDuration] {
        didSet { persistDurations() }
    }

    @Published var defaultDurationID: ActivationDuration.ID {
        didSet { userDefaults.set(defaultDurationID, forKey: Keys.defaultDurationID) }
    }

    var defaultDuration: ActivationDuration {
        availableDurations.first(where: { $0.id == defaultDurationID }) ?? ActivationDuration.minutes(15)
    }

    var sessionOptions: SessionOptions {
        SessionOptions(
            allowDisplaySleep: allowDisplaySleep,
            batteryThreshold: deactivateBelowThreshold ? batteryThreshold : nil,
            stopOnLowPowerMode: deactivateOnLowPowerMode
        )
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let durations = Self.loadDurations(from: userDefaults)
        let savedDefaultID = userDefaults.string(forKey: Keys.defaultDurationID) ?? ActivationDuration.minutes(15).id

        self.startAtLogin = userDefaults.bool(forKey: Keys.startAtLogin)
        self.activateOnLaunch = userDefaults.bool(forKey: Keys.activateOnLaunch)
        self.deactivateBelowThreshold = userDefaults.bool(forKey: Keys.deactivateBelowThreshold)
        self.batteryThreshold = Self.snapThreshold(userDefaults.object(forKey: Keys.batteryThreshold) as? Int ?? 20)
        self.deactivateOnLowPowerMode = userDefaults.bool(forKey: Keys.deactivateOnLowPowerMode)
        self.allowDisplaySleep = userDefaults.bool(forKey: Keys.allowDisplaySleep)
        self.availableDurations = durations
        self.defaultDurationID = durations.contains(where: { $0.id == savedDefaultID })
            ? savedDefaultID
            : ActivationDuration.minutes(15).id
    }

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
        if defaultDurationID == id {
            defaultDurationID = ActivationDuration.minutes(15).id
        }
    }

    func resetDurations() {
        availableDurations = ActivationDuration.defaultDurations
        defaultDurationID = ActivationDuration.minutes(15).id
    }

    func setDefaultDuration(_ id: ActivationDuration.ID) {
        guard availableDurations.contains(where: { $0.id == id }) else { return }
        defaultDurationID = id
    }

    nonisolated static func snapThreshold(_ value: Int) -> Int {
        thresholdStops.min(by: { abs($0 - value) < abs($1 - value) }) ?? 20
    }

    private func persistDurations() {
        guard let data = try? encoder.encode(availableDurations) else { return }
        userDefaults.set(data, forKey: Keys.durations)
    }

    private static func loadDurations(from defaults: UserDefaults) -> [ActivationDuration] {
        guard let data = defaults.data(forKey: Keys.durations),
              let durations = try? JSONDecoder().decode([ActivationDuration].self, from: data),
              !durations.isEmpty else {
            return ActivationDuration.defaultDurations
        }

        return durations.sorted(by: sortDurations)
    }

    private static func sortDurations(lhs: ActivationDuration, rhs: ActivationDuration) -> Bool {
        switch (lhs.isIndefinite, rhs.isIndefinite) {
        case (true, true):
            return false
        case (true, false):
            return false
        case (false, true):
            return true
        case (false, false):
            return lhs.totalSeconds < rhs.totalSeconds
        }
    }
}
