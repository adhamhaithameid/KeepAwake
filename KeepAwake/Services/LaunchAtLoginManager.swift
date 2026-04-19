import Foundation
import ServiceManagement

@MainActor
protocol LaunchAtLoginManaging: AnyObject {
    var isEnabled: Bool { get set }
}

@MainActor
final class LiveLaunchAtLoginManager: LaunchAtLoginManaging {
    var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Leave the status unchanged when macOS rejects the request.
            }
        }
    }
}
