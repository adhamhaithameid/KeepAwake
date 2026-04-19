import Foundation

struct ActivationDuration: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let hours: Int
    let minutes: Int
    let seconds: Int

    init(id: String? = nil, hours: Int, minutes: Int, seconds: Int) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.id = id ?? Self.makeIdentifier(hours: hours, minutes: minutes, seconds: seconds)
    }

    var totalSeconds: Int {
        (hours * 3600) + (minutes * 60) + seconds
    }

    var timeInterval: TimeInterval? {
        isIndefinite ? nil : TimeInterval(totalSeconds)
    }

    var isIndefinite: Bool {
        id == Self.indefinite.id
    }

    var menuTitle: String {
        if isIndefinite {
            return "Indefinitely"
        }
        if totalSeconds == 86400 {
            return "1 day"
        }
        if totalSeconds.isMultiple(of: 3600) {
            let value = totalSeconds / 3600
            return value == 1 ? "1h" : "\(value)h"
        }
        if totalSeconds.isMultiple(of: 60) {
            return "\(totalSeconds / 60)m"
        }
        return "\(hours)h \(minutes)m \(seconds)s"
    }

    static let indefinite = ActivationDuration(id: "indefinite", hours: 0, minutes: 0, seconds: 0)

    static let defaultDurations: [ActivationDuration] = [
        .minutes(15),
        .minutes(30),
        .hours(1),
        .hours(2),
        .hours(3),
        .hours(5),
        .hours(8),
        .hours(12),
        ActivationDuration(id: "builtin-1-day", hours: 24, minutes: 0, seconds: 0),
        .indefinite,
    ]

    static func minutes(_ value: Int) -> ActivationDuration {
        ActivationDuration(id: "builtin-\(value)m", hours: 0, minutes: value, seconds: 0)
    }

    static func hours(_ value: Int) -> ActivationDuration {
        ActivationDuration(id: "builtin-\(value)h", hours: value, minutes: 0, seconds: 0)
    }

    private static func makeIdentifier(hours: Int, minutes: Int, seconds: Int) -> String {
        "custom-\(hours)h-\(minutes)m-\(seconds)s"
    }
}
