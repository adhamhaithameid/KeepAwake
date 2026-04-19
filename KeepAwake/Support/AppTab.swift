import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case settings
    case activationDuration
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .settings:
            "Settings"
        case .activationDuration:
            "Activation Duration"
        case .about:
            "About"
        }
    }

    var icon: String {
        switch self {
        case .settings:
            "gearshape"
        case .activationDuration:
            "clock"
        case .about:
            "info.circle"
        }
    }
}
