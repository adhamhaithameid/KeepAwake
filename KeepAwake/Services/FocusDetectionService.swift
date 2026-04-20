import AppKit
import Foundation

/// Observes macOS Focus Mode and Screen Sharing state changes via
/// NSDistributedNotificationCenter and notifies delegates.
///
/// Neither API requires special entitlements for non-sandboxed apps.
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

    func start() {
        let dnc = DistributedNotificationCenter.default()

        // ── Focus Mode ─────────────────────────────────────────────────────
        // macOS 12+ fires these when the user changes Focus state.
        focusOnObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.notificationcenter.focus.on"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.onFocusEnabled?() }

        focusOffObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.notificationcenter.focus.off"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.onFocusDisabled?() }

        // ── Screen Sharing ────────────────────────────────────────────────
        // Fired by the built-in Screen Sharing and AirPlay receiver.
        sharingStartObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screensharing.started"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.onScreenSharingStarted?() }

        sharingStopObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screensharing.stopped"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.onScreenSharingStopped?() }
    }

    func stop() {
        let dnc = DistributedNotificationCenter.default()
        [focusOnObserver, focusOffObserver, sharingStartObserver, sharingStopObserver]
            .compactMap { $0 }
            .forEach { dnc.removeObserver($0) }
        focusOnObserver = nil
        focusOffObserver = nil
        sharingStartObserver = nil
        sharingStopObserver = nil
    }
}
