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

    init(assertions: WakeAssertionControlling, powerStatusProvider: PowerStatusProviding) {
        self.assertions = assertions
        self.powerStatusProvider = powerStatusProvider
    }

    func start(duration: ActivationDuration, options: SessionOptions) async {
        if activeSession != nil {
            await stop(reason: .replaced)
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

        if let interval = duration.timeInterval {
            expirationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await self?.stop(reason: .expired)
            }
        }

        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self else { return }
                await self.evaluatePowerRules(using: self.powerStatusProvider.currentSnapshot())
            }
        }

        await evaluatePowerRules(using: powerStatusProvider.currentSnapshot())
    }

    func stop(reason: StopReason) async {
        expirationTask?.cancel()
        expirationTask = nil
        monitorTask?.cancel()
        monitorTask = nil
        assertions.deactivate()
        activeSession = nil
        lastStopReason = reason
    }

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
}
