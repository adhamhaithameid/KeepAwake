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
    /// True while a CATransition is animating the icon — prevents refreshAppearance
    /// from overwriting the image and cancelling the in-flight animation.
    private var isTransitioningIcon: Bool = false

    private func observeController() {
        controller.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let nowActive = self.controller.isActive

                    // Animate FIRST — the CATransition must be queued on the layer
                    // before anything changes the button.image, otherwise the
                    // transition misses its window and the image updates instantly.
                    if nowActive != self.wasActive {
                        self.isTransitioningIcon = true
                        self.animateIconTransition(becameActive: nowActive)
                        self.wasActive = nowActive
                        // Clear flag after the animation duration (0.22 s)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
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

    /// Vertical-push icon transition that mirrors `.contentTransition(.numericText())`.
    ///
    /// `numericText` slides digits **up** when a value increases and **down** when
    /// it decreases. We apply the same metaphor to the status icon:
    /// - **Activating**  → icon slides in from **below** ("going up", like a rising number)
    /// - **Deactivating** → icon slides in from **above** ("going down", like a falling number)
    ///
    /// The transition is added to the button layer *before* the image is updated so
    /// Core Animation intercepts the change and animates between the two icon states.
    private func animateIconTransition(becameActive: Bool) {
        guard let layer = statusItem.button?.layer else { return }

        let transition = CATransition()
        transition.type        = .push
        transition.subtype     = becameActive ? .fromBottom : .fromTop
        transition.duration    = 0.22
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(transition, forKey: "iconSlide")

        // Assign the new image immediately after queuing the transition —
        // Core Animation will interpolate between the old and new layer contents.
        statusItem.button?.image = makeStatusImage()
    }

    private func makeStatusImage() -> NSImage? {
        let sfName = controller.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        return NSImage(systemSymbolName: sfName, accessibilityDescription: "KeepAwake")?
            .withSymbolConfiguration(config)
    }

    /// The compact countdown shown in the menu bar, e.g. "42m" or "1h 3m".
    private func glanceableLabel() -> String? {
        guard let session = controller.activeSession else { return nil }
        if session.duration.isIndefinite { return "∞" }
        guard let endsAt = session.endsAt else { return nil }
        let remaining = max(endsAt.timeIntervalSinceNow, 0)
        guard remaining > 0 else { return nil }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        let s = Int(remaining) % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
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
        headerHost.frame = NSRect(x: 0, y: 0, width: 252, height: 78)
        headerItem.view = headerHost
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // ── Pinned quick-duration buttons ─────────────────────────────────
        let pinnedDurations = resolvedPinnedDurations()
        let quickItem = NSMenuItem()
        let quickView = QuickActionsMenuView(
            quickDurations: pinnedDurations,
            defaultDurationID: controller.settings.defaultDurationID,
            activate: { [weak self] duration in
                Task { await self?.controller.activate(duration: duration) }
            }
        )
        let quickHost = NSHostingView(rootView: quickView)
        quickHost.frame = NSRect(x: 0, y: 0, width: 252, height: 88)
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
        let quitItem = NSMenuItem(title: "Quit KeepAwake", action: #selector(quitApp), keyEquivalent: "q")
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
        Task {
            await controller.handleTermination()
            NSApp.terminate(nil)
        }
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
                // ── Status row ───────────────────────────────────────────
                HStack(spacing: 12) {
                    // Pulsing dot + progress ring (decorative — hidden from VoiceOver)
                    ZStack {
                        if let progress = sessionProgress(at: timeline.date) {
                            Circle()
                                .stroke(Color.green.opacity(0.15), lineWidth: 2.5)
                                .frame(width: 26, height: 26)
                            Circle()
                                .trim(from: 0, to: CGFloat(1 - progress))
                                .stroke(
                                    AngularGradient(colors: [.green, .green.opacity(0.3)], center: .center),
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                )
                                .frame(width: 26, height: 26)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.5), value: progress)
                        }
                        PulsingDot(isActive: isActive)
                    }
                    .frame(width: 30)
                    .accessibilityHidden(true) // Status text is the primary VoiceOver source

                    // Text block
                    VStack(alignment: .leading, spacing: 1) {
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
                                .accessibilityLabel(detail) // already reads "14m 51s remaining"
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
                .padding(.horizontal, 14)
                .padding(.top, 9)
                .padding(.bottom, isActive ? 7 : 9)

                // ── Stop button row (live — appears when active) ─────────
                if isActive {
                    Divider()
                        .opacity(0.4)
                        .padding(.horizontal, 14)

                    Button(action: onStop) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Stop Session")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop session")
                    .accessibilityHint("Ends the current KeepAwake session and allows your Mac to sleep normally")
                    .padding(.horizontal, 14)
                    .padding(.bottom, 7)
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

private struct PulsingDot: View {
    let isActive: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .fill(Color.green.opacity(pulse ? 0 : 0.28))
                    .frame(width: pulse ? 22 : 10, height: pulse ? 22 : 10)
                    .animation(
                        .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                        value: pulse
                    )
            }
            Circle()
                .fill(isActive ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 9, height: 9)
                .scaleEffect(isActive && pulse ? 1.12 : 1.0)
                .animation(
                    isActive ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default,
                    value: pulse
                )
                .shadow(color: isActive ? .green.opacity(0.55) : .clear, radius: 4)
        }
        .onAppear { pulse = true }
        .onChange(of: isActive) { newValue in
            pulse = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { pulse = newValue }
        }
    }
}
