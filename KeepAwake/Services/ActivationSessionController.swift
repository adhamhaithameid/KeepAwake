import Foundation

@MainActor
protocol ActivationSessionManaging: AnyObject {
    var activeSession: ActivationSession? { get }
    var lastStopReason: StopReason? { get }
    func start(duration: ActivationDuration, options: SessionOptions) async
    func stop(reason: StopReason) async
}

@MainActor
final class ActivationSessionController: ObservableObject, ActivationSessionManaging {
    @Published private(set) var activeSession: ActivationSession?
    @Published private(set) var lastStopReason: StopReason?

    private let assertions: WakeAssertionControlling
    private let powerStatusProvider: PowerStatusProviding
    private var expirationTask: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?
    /// Observes Low Power Mode changes in real time via NSNotification.
    private var powerStateObserver: Task<Void, Never>?

    init(assertions: WakeAssertionControlling, powerStatusProvider: PowerStatusProviding) {
        self.assertions = assertions
        self.powerStatusProvider = powerStatusProvider
    }

    func start(duration: ActivationDuration, options: SessionOptions) async {
        if activeSession != nil {
            await stop(reason: .replaced)
        }

        // Refuse to start if Low Power Mode is on and the option is set.
        let currentSnapshot = powerStatusProvider.currentSnapshot()
        if options.stopOnLowPowerMode && currentSnapshot.isLowPowerModeEnabled {
            lastStopReason = .lowPowerMode
            return
        }

        do {
            try assertions.activate(allowDisplaySleep: options.allowDisplaySleep)
        } catch {
            lastStopReason = .manual
            return
        }

        let now = Date()
        let endsAt = duration.timeInterval.map { now.addingTimeInterval($0) }
        activeSession = ActivationSession(duration: duration, startedAt: now, endsAt: endsAt, options: options)
        lastStopReason = nil

        // ── Session expiration timer ────────────────────────────────────────
        if let interval = duration.timeInterval {
            expirationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await self?.stop(reason: .expired)
            }
        }

        // ── Periodic battery/power poll (every 30 s) ───────────────────────
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                await self.evaluatePowerRules(using: self.powerStatusProvider.currentSnapshot())
            }
        }

        // ── Reactive Low Power Mode observation ────────────────────────────
        // NSProcessInfoPowerStateDidChange fires immediately when the user
        // toggles Low Power Mode, giving sub-second response instead of
        // waiting for the next 30-second poll.
        startPowerStateObserver(options: options)
    }

    func stop(reason: StopReason) async {
        expirationTask?.cancel()
        expirationTask = nil
        monitorTask?.cancel()
        monitorTask = nil
        powerStateObserver?.cancel()
        powerStateObserver = nil
        assertions.deactivate()
        activeSession = nil
        lastStopReason = reason
    }

    // MARK: - Power rule evaluation

    func evaluatePowerRules(using snapshot: PowerSnapshot) async {
        guard let activeSession else { return }

        if let threshold = activeSession.options.batteryThreshold,
           let batteryLevel = snapshot.batteryLevel,
           batteryLevel < threshold {
            await stop(reason: .batteryThreshold)
            return
        }

        if activeSession.options.stopOnLowPowerMode,
           snapshot.isLowPowerModeEnabled {
            await stop(reason: .lowPowerMode)
        }
    }

    // MARK: - Private

    private func startPowerStateObserver(options: SessionOptions) {
        guard options.stopOnLowPowerMode else { return }  // Nothing to observe

        powerStateObserver = Task { [weak self] in
            // Observe ProcessInfo power state change notifications.
            let notifications = NotificationCenter.default.notifications(
                named: .NSProcessInfoPowerStateDidChange
            )
            for await _ in notifications {
                guard let self, !Task.isCancelled else { return }
                // Evaluate immediately when the notification fires.
                await self.evaluatePowerRules(
                    using: self.powerStatusProvider.currentSnapshot()
                )
            }
        }
    }
}
