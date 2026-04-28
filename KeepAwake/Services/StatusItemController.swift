import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let controller: KeepAwakeController
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []
    /// Fires every second to keep the menu-bar label countdown live.
    private var labelTimer: Timer?

    init(controller: KeepAwakeController) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        observeController()
        refreshAppearance()
        // UX-5: Flash the icon whenever a timed session expires.
        controller.onSessionExpired = { [weak self] in
            self?.scheduleExpireFlash()
        }
    }

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.imagePosition = .imageOnly
        button.toolTip = "KeepAwake — ⌥ click to activate default immediately"
        button.imageScaling = .scaleProportionallyDown
        _ = button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private var wasActive: Bool = false
    /// True while an icon animation is in flight — prevents refreshAppearance
    /// from overwriting the image mid-animation.
    private var isTransitioningIcon: Bool = false
    /// Set to true when a timed session becomes inactive so the expire-flash
    /// fires on the next objectWillChange delivery (UX-5).
    private var wasFlashPending: Bool = false

    private func observeController() {
        controller.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let nowActive = self.controller.isActive

                    // Animate FIRST — the animation must be queued on the layer
                    // before anything changes the button.image, otherwise the
                    // transition misses its window and the image updates instantly.
                    if nowActive != self.wasActive {
                        self.isTransitioningIcon = true
                        self.animateIconTransition(becameActive: nowActive)
                        self.wasActive = nowActive
                        // Clear flag after the animation duration (0.25 s)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
                            self?.isTransitioningIcon = false
                        }
                    }

                    // Timer overlap fix: kill the timer in the SAME tick that
                    // isActive becomes false — not waiting for the next 1-sec fire.
                    self.syncLabelTimer()
                    // refreshAppearance will skip the image update during a transition.
                    self.refreshAppearance()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Label timer

    private func syncLabelTimer() {
        let shouldRun = controller.isActive && controller.settings.showStatusLabel
        if shouldRun && labelTimer == nil {
            labelTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                DispatchQueue.main.async { self?.refreshAppearance() }
            }
        } else if !shouldRun {
            labelTimer?.invalidate()
            labelTimer = nil
        }
    }

    // MARK: - Appearance

    private func refreshAppearance() {
        guard let button = statusItem.button else { return }

        // Don't overwrite the image while a CATransition is in flight —
        // animateIconTransition already set the new image as part of the animation.
        if !isTransitioningIcon {
            button.image = makeStatusImage()
        }

        let showLabel = controller.isActive && controller.settings.showStatusLabel
        if showLabel, let text = glanceableLabel() {
            button.title = " \(text)"
            button.imagePosition = .imageLeft
            statusItem.length = NSStatusItem.variableLength
        } else {
            // Clear label immediately — don't wait for timer's next tick.
            button.title = ""
            button.imagePosition = .imageOnly
            statusItem.length = NSStatusItem.squareLength
        }
    }

    /// Smooth cross-dissolve icon transition using CAKeyframeAnimation (IA-1).
    ///
    /// Replaces the previous `CATransition.push` which could produce a brief
    /// flicker on high-DPI Retina displays because the push transition renders
    /// the old and new contents side-by-side at sub-pixel boundaries.
    ///
    /// The new approach animates `opacity` (fade out old, fade in new) combined
    /// with a tiny `transform.scale` spring for a lively but non-jarring feel:
    /// - **Activating** — scale 0.8 → 1.05 → 1.0 ("growing", like a rising number)
    /// - **Deactivating** — scale 1.0 → 0.85 → 1.0 ("shrinking", like a falling number)
    private func animateIconTransition(becameActive: Bool) {
        guard let layer = statusItem.button?.layer else { return }

        // Opacity: quick fade out then back in around the image swap.
        let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnim.values   = [1.0, 0.0, 1.0]
        opacityAnim.keyTimes = [0, 0.4, 1.0]
        opacityAnim.duration = 0.25
        opacityAnim.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .easeOut)
        ]
        layer.add(opacityAnim, forKey: "iconFade")

        // Scale: spring bounce on the way in.
        let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
        if becameActive {
            scaleAnim.values   = [0.80, 1.05, 1.0]
            scaleAnim.keyTimes = [0, 0.65, 1.0]
        } else {
            scaleAnim.values   = [1.0, 0.82, 1.0]
            scaleAnim.keyTimes = [0, 0.55, 1.0]
        }
        scaleAnim.duration = 0.25
        scaleAnim.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .easeOut)
        ]
        layer.add(scaleAnim, forKey: "iconScale")

        // Assign the new image at the midpoint (opacity == 0) so the swap is invisible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.statusItem.button?.image = self?.makeStatusImage()
        }
    }

    // MARK: - Session-expire flash (UX-5)

    /// Briefly flashes the menu-bar icon amber when a timed session expires,
    /// giving the user a visual cue that their session has ended even if they
    /// are not looking at the menu bar at that moment.
    func scheduleExpireFlash() {
        wasFlashPending = true
    }

    private func flashIconExpired() {
        guard let layer = statusItem.button?.layer else { return }
        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values   = [1.0, 0.2, 1.0, 0.3, 1.0]
        flash.keyTimes = [0, 0.15, 0.35, 0.55, 1.0]
        flash.duration = 0.7
        flash.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 4)
        layer.add(flash, forKey: "expireFlash")
    }

    private func makeStatusImage() -> NSImage? {
        // Use SF Symbols for the status icon — they are vector, crisp at all
        // resolutions, and tint automatically for dark/light menu bar.
        //
        // The custom PNG assets (MenuBarCoffeeFilled/Outline) are bitmaps baked
        // at a fixed size and render blurry when AppKit scales them for Retina,
        // so we keep the proven SF Symbol approach from the original implementation.
        let sfName = controller.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let base = NSImage(systemSymbolName: sfName, accessibilityDescription: "KeepAwake")?
            .withSymbolConfiguration(config) else { return nil }

        // UX-1: When the countdown label is hidden, draw a small green dot badge
        // in the corner so there's always a visible active-session indicator.
        guard controller.isActive, !controller.settings.showStatusLabel else {
            return base
        }

        // Compose badge onto a copy at the natural symbol size.
        let size = base.size
        let badgeD: CGFloat = 5

        let composited = NSImage(size: size, flipped: false) { _ in
            base.draw(in: NSRect(origin: .zero, size: size))
            let badgeRect = NSRect(x: size.width - badgeD - 1, y: 1, width: badgeD, height: badgeD)
            NSColor.systemGreen.setFill()
            NSBezierPath(ovalIn: badgeRect).fill()
            NSColor.white.withAlphaComponent(0.80).setStroke()
            let ring = NSBezierPath(ovalIn: badgeRect.insetBy(dx: 0.5, dy: 0.5))
            ring.lineWidth = 0.75
            ring.stroke()
            return true
        }
        composited.isTemplate = true  // still template so AppKit tints it for menu bar state
        return composited
    }


    /// The compact countdown shown in the menu bar, e.g. "42m" or "1h 3m".
    /// Uses a fixed-width monospaced format so the status item doesn't shift
    /// horizontally as seconds tick down (IA-3).
    private func glanceableLabel() -> String? {
        guard let session = controller.activeSession else { return nil }
        if session.duration.isIndefinite { return "∞" }
        guard let endsAt = session.endsAt else { return nil }
        let remaining = max(endsAt.timeIntervalSinceNow, 0)
        guard remaining > 0 else { return nil }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        let s = Int(remaining) % 60
        // Always include seconds so the label width is stable (e.g. "1h 3m 5s",
        // "42m 7s", "58s") — prevents the status item from jumping position.
        if h > 0 { return String(format: "%dh %dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }

    // MARK: - Click handling

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let isRight = event.type == .rightMouseUp
        let isCtrl  = event.type == .leftMouseUp && event.modifierFlags.contains(.control)
        let isOpt   = event.type == .leftMouseUp && event.modifierFlags.contains(.option)

        if isOpt {
            Task { await controller.activateDefault() }
        } else if isRight || isCtrl {
            showMenu()
        } else {
            Task { await controller.handlePrimaryClick() }
        }
    }

    // MARK: - Menu

    private func showMenu() {
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
        refreshAppearance()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // ── Live header: status + countdown + battery + STOP BUTTON ─────────
        // The header height is always generous (80px) so the Stop button can
        // appear/disappear via SwiftUI's @ObservedObject binding without
        // needing to rebuild the NSMenu.
        let headerItem = NSMenuItem()
        let headerView = MenuHeaderView(controller: controller, onStop: { [weak self] in
            Task { await self?.controller.stopActiveSession() }
        })
        let headerHost = NSHostingView(rootView: headerView)
        // Inactive: status row ~60pt. Active: status row + divider + stop button ~108pt.
        // We use a fixed generous height and let SwiftUI clip at bottom rather than
        // having dead whitespace — the view is top-aligned inside the frame.
        let headerHeight: CGFloat = controller.isActive ? 110 : 68
        headerHost.frame = NSRect(x: 0, y: 0, width: 260, height: headerHeight)
        headerHost.autoresizingMask = []
        headerItem.view = headerHost
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // ── Pinned quick-duration buttons ─────────────────────────────────
        let pinnedDurations = resolvedPinnedDurations()
        let quickItem = NSMenuItem()
        let quickView = QuickActionsMenuView(
            quickDurations: pinnedDurations,
            defaultDurationID: controller.settings.defaultDurationID,
            activeDurationID: controller.activeSession?.duration.id,
            activate: { [weak self] duration in
                Task { await self?.controller.activate(duration: duration) }
            }
        )
        let quickHost = NSHostingView(rootView: quickView)
        quickHost.frame = NSRect(x: 0, y: 0, width: 260, height: 88)
        quickItem.view = quickHost
        menu.addItem(quickItem)

        menu.addItem(.separator())

        // ── Overflow submenu ───────────────────────────────────────────────
        let pinnedIDs = Set(pinnedDurations.map(\.id))
        let overflowDurations = controller.settings.availableDurations
            .filter { !pinnedIDs.contains($0.id) }

        if !overflowDurations.isEmpty {
            let submenuItem = NSMenuItem(title: "Activate for Duration", action: nil, keyEquivalent: "")
            submenuItem.isEnabled = true
            let submenu = NSMenu(title: "Activate for Duration")
            for duration in overflowDurations {
                let item = NSMenuItem(
                    title: duration.menuTitle,
                    action: #selector(handleDurationSelection(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = duration
                item.isEnabled = true
                submenu.addItem(item)
            }
            submenuItem.submenu = submenu
            menu.addItem(submenuItem)
            menu.addItem(.separator())
        }

        // ── Settings ──────────────────────────────────────────────────────
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.isEnabled = true
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        // ── Quit ──────────────────────────────────────────────────────────
        // No keyEquivalent here — ⌘Q already triggers NSApp.terminate via the
        // standard Application menu; a duplicate binding conflicts when the
        // Settings window is key (UX-10).
        let quitItem = NSMenuItem(title: "Quit KeepAwake", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        quitItem.isEnabled = true
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Helpers

    private func resolvedPinnedDurations() -> [ActivationDuration] {
        let available = controller.settings.availableDurations
        return controller.settings.pinnedDurationIDs
            .compactMap { id in available.first { $0.id == id } }
    }

    // MARK: - Actions

    @objc private func handleDurationSelection(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? ActivationDuration else { return }
        Task { await controller.activate(duration: duration) }
    }

    @objc private func openSettings() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.controller.openSettings(selectedTab: .settings)
        }
    }

    @objc private func quitApp() {
        // Do NOT call controller.handleTermination() here.
        // AppDelegate.applicationWillTerminate owns all cleanup via terminateSync().
        // Calling handleTermination() here as well causes a double-teardown:
        // the assertion would be released twice and tasks cancelled twice.
        NSApp.terminate(nil)
    }
}

// MARK: - MenuHeaderView

/// Live header view embedded in the NSMenu.
/// Uses @ObservedObject so it updates in real-time as the session state changes —
/// including showing/hiding the Stop button without rebuilding the NSMenu.
///
/// ## Accessibility
/// - Status text ("Active"/"Inactive") is marked as a header trait.
/// - Countdown text ("14m 51s remaining") is read verbatim by VoiceOver.
/// - The pulsing dot + ring are hidden from VoiceOver (decorative).
/// - Stop button has a label + hint describing the destructive action.
private struct MenuHeaderView: View {
    @ObservedObject var controller: KeepAwakeController
    let onStop: () -> Void

    private var isActive: Bool { controller.isActive }
    private var session: ActivationSession? { controller.activeSession }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            VStack(spacing: 0) {

                // ── Status row ──────────────────────────────────────────
                HStack(spacing: 10) {
                    // Pulsing dot + circular progress ring
                    ZStack {
                        if let progress = sessionProgress(at: timeline.date) {
                            Circle()
                                .stroke(Color.green.opacity(0.15), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            Circle()
                                .trim(from: 0, to: CGFloat(1 - progress))
                                .stroke(
                                    AngularGradient(colors: [.green, .green.opacity(0.3)], center: .center),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                )
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.5), value: progress)
                        }
                        PulsingDot(isActive: isActive)
                    }
                    .frame(width: 28)
                    .accessibilityHidden(true)

                    // Status text + detail
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isActive ? "Active" : "Inactive")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isActive ? Color.green : Color.secondary)
                            .accessibilityAddTraits(.isHeader)

                        if let detail = detailText(at: timeline.date) {
                            Text(detail)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.secondary)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.15), value: detail)
                                .accessibilityLabel(detail)
                        }

                        if controller.settings.deactivateBelowThreshold,
                           let batt = controller.currentBatteryLevel {
                            Text("Battery \(batt)% — stops at \(controller.settings.batteryThreshold)%")
                                .font(.system(size: 10))
                                .foregroundStyle(
                                    batt <= controller.settings.batteryThreshold + 5
                                        ? Color.orange : Color.secondary.opacity(0.7)
                                )
                                .accessibilityLabel("Battery at \(batt) percent. Session stops at \(controller.settings.batteryThreshold) percent.")
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 10)

                // ── Assertion error banner ──────────────────────────────
                if let errorMsg = controller.lastAssertionError {
                    Divider().opacity(0.35).padding(.horizontal, 12)
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.orange)
                        Text(errorMsg)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.orange)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityLabel("Error: \(errorMsg)")
                }

                // ── Stop Session button ─────────────────────────────────
                if isActive {
                    Divider().opacity(0.35).padding(.horizontal, 12)

                    Button(action: onStop) {
                        HStack(spacing: 5) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Stop Session")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop session")
                    .accessibilityHint("Ends the current KeepAwake session")
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
    }

    // MARK: - Helpers

    private func sessionProgress(at now: Date) -> Double? {
        guard let s = session, let endsAt = s.endsAt else { return nil }
        let total = endsAt.timeIntervalSince(s.startedAt)
        guard total > 0 else { return nil }
        return min(max(now.timeIntervalSince(s.startedAt) / total, 0), 1)
    }

    private func detailText(at now: Date) -> String? {
        guard let s = session else { return nil }
        if s.duration.isIndefinite { return "Indefinitely" }
        guard let endsAt = s.endsAt else { return nil }
        let rem = max(endsAt.timeIntervalSince(now), 0)
        if rem <= 0 { return "Ending…" }
        let h = Int(rem) / 3600
        let m = (Int(rem) % 3600) / 60
        let sc = Int(rem) % 60
        if h > 0 { return "\(h)h \(m)m \(sc)s remaining" }
        if m > 0 { return "\(m)m \(sc)s remaining" }
        return "\(sc)s remaining"
    }
}


// MARK: - PulsingDot

/// A pulsing activity indicator shown in the menu header.
///
/// ## Race-condition fix (IA-2)
/// The previous implementation used `DispatchQueue.asyncAfter` to reset the
/// `pulse` state on `isActive` change. Rapid activate→stop→activate sequences
/// could leave the timer orphaned and the dot stuck in a half-animated state.
///
/// The fix: derive `pulse` from `isActive` directly inside the view body and
/// let SwiftUI's diffing ensure the animations restart cleanly on each change.
private struct PulsingDot: View {
    let isActive: Bool
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .fill(Color.green.opacity(isPulsing ? 0 : 0.28))
                    .frame(width: isPulsing ? 22 : 10, height: isPulsing ? 22 : 10)
                    .animation(
                        .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            }
            Circle()
                .fill(isActive ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 9, height: 9)
                .scaleEffect(isActive && isPulsing ? 1.12 : 1.0)
                .animation(
                    isActive ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default,
                    value: isPulsing
                )
                .shadow(color: isActive ? .green.opacity(0.55) : .clear, radius: 4)
        }
        .onAppear {
            if isActive { isPulsing = true }
        }
        .onChange(of: isActive) { newValue in
            // Reset first so SwiftUI sees a value change and restarts animations.
            isPulsing = false
            if newValue {
                // One tick delay lets SwiftUI commit the reset before starting pulse.
                withAnimation(.easeInOut(duration: 0)) { isPulsing = true }
            }
        }
    }
}
