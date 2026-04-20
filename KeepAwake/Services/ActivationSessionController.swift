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

    // Tasks
    private var expirationTask: Task<Void, Never>?
    private var warningTask: Task<Void, Never>?   // fires at session - 5 min
    private var monitorTask: Task<Void, Never>?
    private var powerStateObserver: Task<Void, Never>?

    // Push-based battery monitor (replaces 30 s poll for battery checks)
    private let batteryMonitor = BatteryMonitor()

    init(assertions: WakeAssertionControlling, powerStatusProvider: PowerStatusProviding) {
        self.assertions = assertions
        self.powerStatusProvider = powerStatusProvider
    }

    // MARK: - Start

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

        // Set activeSession optimistically so isActive flips synchronously —
        // ensuring the Stop button appears on the very next menu open.
        let now = Date()
        let endsAt = duration.timeInterval.map { now.addingTimeInterval($0) }
        activeSession = ActivationSession(duration: duration, startedAt: now, endsAt: endsAt, options: options)
        lastStopReason = nil

        // IOKit assertion (synchronous, never suspends on MainActor).
        do {
            try assertions.activate(allowDisplaySleep: options.allowDisplaySleep,
                                    allowPowerNap: options.allowPowerNap)
        } catch {
            activeSession = nil
            lastStopReason = .manual
            return
        }

        // ── Expiration timer ──────────────────────────────────────────────
        if let interval = duration.timeInterval {
            expirationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await self?.stop(reason: .expired)
            }

            // ── Auto-extend warning (fires 5 min before end) ──────────────
            let warningInterval = max(interval - 5 * 60, 0)
            if interval > 5 * 60 {   // only if session is longer than 5 min
                warningTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(warningInterval))
                    guard !Task.isCancelled, let self else { return }
                    await self.fireExpiryWarning(duration: duration)
                }
            }
        }

        // ── Push-based battery monitoring ─────────────────────────────────
        // IOPSNotificationCreateRunLoopSource fires the moment charge changes —
        // same mechanism as the system battery icon. Replaces the 30-second poll.
        batteryMonitor.onBatteryChange = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.evaluatePowerRules(using: self.powerStatusProvider.currentSnapshot())
            }
        }
        batteryMonitor.start()

        // ── Reactive Low Power Mode observer ───────────────────────────────
        startPowerStateObserver(options: options)
    }

    // MARK: - Stop

    func stop(reason: StopReason) async {
        expirationTask?.cancel(); expirationTask = nil
        warningTask?.cancel();    warningTask = nil
        monitorTask?.cancel();    monitorTask = nil
        powerStateObserver?.cancel(); powerStateObserver = nil
        batteryMonitor.stop()
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

        if activeSession.options.stopOnLowPowerMode, snapshot.isLowPowerModeEnabled {
            await stop(reason: .lowPowerMode)
        }
    }

    // MARK: - Private

    private func startPowerStateObserver(options: SessionOptions) {
        guard options.stopOnLowPowerMode else { return }
        powerStateObserver = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .NSProcessInfoPowerStateDidChange
            )
            for await _ in notifications {
                guard let self, !Task.isCancelled else { return }
                await self.evaluatePowerRules(using: self.powerStatusProvider.currentSnapshot())
            }
        }
    }

    private func fireExpiryWarning(duration: ActivationDuration) async {
        guard activeSession != nil else { return }
        NotificationManager.shared.notifyExpiryWarning(duration: duration)
    }
}
