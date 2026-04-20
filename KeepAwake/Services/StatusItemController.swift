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

    private func observeController() {
        controller.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshAppearance()
                    self?.syncLabelTimer()
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
        button.image = makeStatusImage()

        let showLabel = controller.isActive && controller.settings.showStatusLabel
        if showLabel, let text = glanceableLabel() {
            button.title = " \(text)"
            button.imagePosition = .imageLeft
            statusItem.length = NSStatusItem.variableLength
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
            statusItem.length = NSStatusItem.squareLength
        }
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

/// Live header view embedded in the NSMenu. Because it uses @ObservedObject,
/// it updates in real-time as the session state changes — including showing
/// and hiding the Stop button without requiring a menu rebuild.
private struct MenuHeaderView: View {
    @ObservedObject var controller: KeepAwakeController
    let onStop: () -> Void

    private var isActive: Bool { controller.isActive }
    private var session: ActivationSession? { controller.activeSession }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            VStack(spacing: 0) {
                // ── Status row ─────────────────────────────────────────
                HStack(spacing: 12) {
                    // Animated pulse dot + progress ring
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

                    // Text block
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isActive ? "Active" : "Inactive")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isActive ? Color.green : Color.secondary)

                        if let detail = detailText(at: timeline.date) {
                            Text(detail)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.secondary)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.15), value: detail)
                        }

                        if controller.settings.deactivateBelowThreshold,
                           let batt = controller.currentBatteryLevel {
                            Text("Battery \(batt)% — stops at \(controller.settings.batteryThreshold)%")
                                .font(.system(size: 10))
                                .foregroundStyle(
                                    batt <= controller.settings.batteryThreshold + 5
                                        ? Color.orange : Color.secondary.opacity(0.7)
                                )
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 9)
                .padding(.bottom, isActive ? 7 : 9)

                // ── Stop button row (live — appears when active) ───────
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
