import Foundation
import UserNotifications

/// Manages user-facing notifications for KeepAwake.
/// Requests permission on first use and schedules alerts for auto-stop events.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private var isAuthorized = false

    private init() {}

    /// Call once at launch to request notification permission.
    func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        self?.isAuthorized = granted
                    }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { self?.isAuthorized = true }
            default:
                DispatchQueue.main.async { self?.isAuthorized = false }
            }
        }
    }

    /// Fires a notification explaining why a session was stopped automatically.
    func notifyAutoStop(reason: StopReason) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "KeepAwake Stopped"
        content.sound = .defaultCritical

        switch reason {
        case .lowPowerMode:
            content.body = "Your session was stopped because Low Power Mode was enabled."
        case .batteryThreshold:
            content.body = "Your session was stopped because battery level dropped below your threshold."
        case .expired:
            content.body = "Your activation session has ended."
        default:
            return  // Don't notify for manual/app-termination stops
        }

        let request = UNNotificationRequest(
            identifier: "com.keepawake.autostop.\(UUID().uuidString)",
            content: content,
            trigger: nil  // Deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
