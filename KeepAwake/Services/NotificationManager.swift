import Foundation
import UserNotifications

/// Manages user-facing notifications for KeepAwake.
/// Handles permission, schedules alerts for auto-stop events,
/// and provides expiry-warning notifications with an "Extend +30m" action.
///
/// ## Compatibility
/// This class uses `UNUserNotificationCenter` (introduced macOS 10.14) which
/// supersedes the deprecated `NSUserNotificationCenter` removed in macOS 14.
/// `UNNotificationPresentationOptions.banner` and `.sound` require macOS 11+.
/// KeepAwake targets **macOS 13**, so all options used here are fully available.
///
/// `UNNotificationAction` and `UNNotificationCategory` are available macOS 10.14+.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    // Notification identifiers — nonisolated so the delegate callbacks can access them
    nonisolated static let extendActionID = "KEEPAWAKE_EXTEND_30M"
    nonisolated static let expiryWarningCategoryID = "KEEPAWAKE_EXPIRY_WARNING"
    nonisolated static let expiryWarningNotifID = "com.keepawake.expiry-warning"

    /// Called when the user taps "Extend +30m" in the expiry-warning banner.
    var onExtendRequested: (() -> Void)?

    private var isAuthorized = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Setup

    /// Call once at launch to request notification permission and register categories.
    func requestPermissionIfNeeded() {
        registerCategories()
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    DispatchQueue.main.async { self?.isAuthorized = granted }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { self?.isAuthorized = true }
            default:
                DispatchQueue.main.async { self?.isAuthorized = false }
            }
        }
    }

    private func registerCategories() {
        let extendAction = UNNotificationAction(
            identifier: Self.extendActionID,
            title: "Extend +30m",
            options: []
        )
        let warningCategory = UNNotificationCategory(
            identifier: Self.expiryWarningCategoryID,
            actions: [extendAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([warningCategory])
    }

    // MARK: - Notifications

    /// Fires when ≤ 5 minutes remain in the current session.
    func notifyExpiryWarning(duration: ActivationDuration) {
        // Remove any stale warning before posting a fresh one.
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.expiryWarningNotifID])

        let content = UNMutableNotificationContent()
        content.title = "KeepAwake — Session Ending Soon"
        content.body = "Your \(duration.menuTitle) session ends in under 5 minutes."
        content.sound = .default
        content.categoryIdentifier = Self.expiryWarningCategoryID

        let request = UNNotificationRequest(
            identifier: Self.expiryWarningNotifID,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Fires when a session is stopped automatically (Low Power Mode, battery, expired).
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
            return  // Don't notify for manual/app-termination/replaced stops.
        }

        let request = UNNotificationRequest(
            identifier: "com.keepawake.autostop.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == Self.extendActionID {
            DispatchQueue.main.async {
                self.onExtendRequested?()
            }
        }
        completionHandler()
    }

    /// Show banners even when the app is in the foreground (menu bar app).
    /// `.banner` and `.sound` require macOS 11+ — satisfied by our macOS 13 target.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // .banner is the modern replacement for .alert (deprecated macOS 12).
        // Both are valid on macOS 11–14, but .banner is preferred.
        completionHandler([.banner, .sound])
    }
}
