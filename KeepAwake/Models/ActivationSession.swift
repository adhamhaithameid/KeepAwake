import Foundation

struct SessionOptions: Equatable {
    var allowDisplaySleep: Bool
    var allowPowerNap: Bool
    var batteryThreshold: Int?
    var stopOnLowPowerMode: Bool

    static let `default` = SessionOptions(
        allowDisplaySleep: false,
        allowPowerNap: false,
        batteryThreshold: nil,
        stopOnLowPowerMode: false
    )
}

enum StopReason: Equatable {
    case manual
    case replaced
    case expired
    case batteryThreshold
    case lowPowerMode
    case appTermination
}

struct ActivationSession: Equatable {
    let duration: ActivationDuration
    let startedAt: Date
    let endsAt: Date?
    let options: SessionOptions

    var isIndefinite: Bool {
        endsAt == nil
    }
}
