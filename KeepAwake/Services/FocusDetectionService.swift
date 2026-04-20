import AppKit
import Foundation

/// Observes macOS Focus Mode and Screen Sharing state changes.
///
/// ## Strategy (multi-layer reliability)
///
/// 1. **Primary**: `NSDistributedNotificationCenter` — catches Focus transitions
///    on macOS 12+ in real-time (undocumented but widely used and stable).
/// 2. **Fallback**: 15-second poll reading the `doNotDisturb` key from the
///    `com.apple.notificationcenterui` shared UserDefaults suite — available
///    even when distributed notifications are suppressed.
/// 3. **Screen Sharing**: distributed notification only; no public poll API.
///
/// Neither mechanism requires special entitlements on non-sandboxed apps.
@MainActor
final class FocusDetectionService {

    /// Called when Focus Mode turns on.
    var onFocusEnabled: (() -> Void)?
    /// Called when Focus Mode turns off.
    var onFocusDisabled: (() -> Void)?
    /// Called when Screen Sharing begins.
    var onScreenSharingStarted: (() -> Void)?
    /// Called when Screen Sharing ends.
    var onScreenSharingStopped: (() -> Void)?

    private var focusOnObserver: NSObjectProtocol?
    private var focusOffObserver: NSObjectProtocol?
    private var sharingStartObserver: NSObjectProtocol?
    private var sharingStopObserver: NSObjectProtocol?
    private var fallbackPollTask: Task<Void, Never>?
    /// Last known Focus state — used by the fallback poll to detect changes.
    private var lastKnownFocusState: Bool = false

    // MARK: - Start / Stop

    func start() {
        registerDistributedObservers()
        startFallbackPoll()
    }

    func stop() {
        unregisterDistributedObservers()
        fallbackPollTask?.cancel()
        fallbackPollTask = nil
    }

    // MARK: - Distributed notifications (primary path)

    private func registerDistributedObservers() {
        let dnc = DistributedNotificationCenter.default()

        // macOS 12+ fires these synchronously when Focus state changes.
        focusOnObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.notificationcenter.focus.on"),
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.lastKnownFocusState = true
            self.onFocusEnabled?()
        }

        focusOffObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.notificationcenter.focus.off"),
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.lastKnownFocusState = false
            self.onFocusDisabled?()
        }

        // Screen Sharing / AirPlay receiver
        sharingStartObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screensharing.started"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.onScreenSharingStarted?() }

        sharingStopObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screensharing.stopped"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.onScreenSharingStopped?() }
    }

    private func unregisterDistributedObservers() {
        let dnc = DistributedNotificationCenter.default()
        [focusOnObserver, focusOffObserver, sharingStartObserver, sharingStopObserver]
            .compactMap { $0 }
            .forEach { dnc.removeObserver($0) }
        focusOnObserver  = nil
        focusOffObserver = nil
        sharingStartObserver  = nil
        sharingStopObserver   = nil
    }

    // MARK: - Fallback poll (secondary path, every 15 s)

    /// Reads the `doNotDisturb` flag from the notification-center shared suite.
    /// This is a documented-ish UserDefaults key that macOS writes on Focus transitions.
    /// We use it only as a safety net if the distributed notifications don't fire.
    private func startFallbackPoll() {
        fallbackPollTask = Task { [weak self] in
            // Seed the initial state without firing callbacks.
            self?.lastKnownFocusState = Self.readDoNotDisturbState()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self, !Task.isCancelled else { return }

                let currentState = Self.readDoNotDisturbState()
                if currentState != self.lastKnownFocusState {
                    self.lastKnownFocusState = currentState
                    if currentState {
                        self.onFocusEnabled?()
                    } else {
                        self.onFocusDisabled?()
                    }
                }
            }
        }
    }

    /// Reads the shared `com.apple.notificationcenterui` UserDefaults suite.
    /// Key `doNotDisturb` (legacy DND) and `dndOn` (Focus mode) are both checked.
    private nonisolated static func readDoNotDisturbState() -> Bool {
        let suite = UserDefaults(suiteName: "com.apple.notificationcenterui")
        // macOS 12 and later use "dndOn"; earlier versions used "doNotDisturb".
        return suite?.bool(forKey: "dndOn") == true
            || suite?.bool(forKey: "doNotDisturb") == true
    }
}
