import AppKit
import SwiftUI

/// Full-screen onboarding window shown on first launch.
/// Guides the user through: welcome → how-to-use → notifications.
struct OnboardingView: View {
    @State private var page: Int = 0
    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "cup.and.saucer.fill",
            imageColor: Color(red: 0.42, green: 0.67, blue: 0.84),
            title: "Welcome to KeepAwake",
            body: "Keep your Mac awake on demand — during presentations, long downloads, or whenever sleep would get in the way.",
            footnote: nil
        ),
        OnboardingPage(
            systemImage: "cursorarrow.click",
            imageColor: .accentColor,
            title: "Three ways to activate",
            body: "",
            footnote: nil,
            bullets: [
                ("cursorarrow.click", "Left click", "Toggle the active session on or off"),
                ("option", "⌥ + click", "Activate your default duration instantly"),
                ("contextualmenu.and.cursorarrow", "Right click", "Open the full menu with all options"),
            ]
        ),
        OnboardingPage(
            systemImage: "bell.badge.fill",
            imageColor: .orange,
            title: "Stay informed",
            body: "KeepAwake can notify you when a session ends, or when it's stopped automatically by Low Power Mode or a low battery.",
            footnote: "We'll ask for permission now — you can change this any time in System Settings."
        ),
    ]

    var body: some View {
        ZStack {
            // Background
            VisualEffectBlur()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Manual horizontal pager (macOS-compatible)
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, p in
                            pageView(p)
                                .frame(width: geo.size.width)
                        }
                    }
                    .offset(x: -CGFloat(page) * geo.size.width)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)
                }
                .frame(height: 360)
                .clipped()

                Spacer()

                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: i == page ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.bottom, 28)

                // Navigation buttons
                HStack(spacing: 12) {
                    if page > 0 {
                        Button("Back") { page -= 1 }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Back")
                            .accessibilityHint("Go to the previous onboarding step")
                    }

                    // Skip — always visible, marks onboarding complete without
                    // completing all slides, preventing the window from
                    // re-appearing on every launch.
                    if page < pages.count - 1 {
                        Button("Skip") { onComplete() }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                            .accessibilityLabel("Skip onboarding")
                            .accessibilityHint("Close this welcome screen and go straight to the app")
                    }

                    Spacer()

                    if page < pages.count - 1 {
                        Button("Next") { page += 1 }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            .accessibilityLabel("Next")
                            .accessibilityHint("Go to the next onboarding step")
                    } else {
                        Button("Get Started") {
                            onComplete()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .accessibilityLabel("Get Started")
                        .accessibilityHint("Finish setup and start using KeepAwake")
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
        }
        .frame(width: 520, height: 500)
        .onChange(of: page) { newPage in
            // Request notification permission when the user reaches the notifications slide
            if newPage == pages.count - 1 {
                NotificationManager.shared.requestPermissionIfNeeded()
            }
        }
    }

    // MARK: - Page view

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            // Hero icon
            ZStack {
                Circle()
                    .fill(page.imageColor.opacity(0.15))
                    .frame(width: 90, height: 90)
                Image(systemName: page.systemImage)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(page.imageColor)
            }
            .accessibilityHidden(true)   // Decorative; title provides the context

            // Title
            Text(page.title)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            // Body or bullets
            if !page.bullets.isEmpty {
                VStack(spacing: 14) {
                    ForEach(page.bullets, id: \.0) { bullet in
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: bullet.0)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bullet.1)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(bullet.2)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(bullet.1): \(bullet.2)")
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
            } else if !page.body.isEmpty {
                Text(page.body)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let footnote = page.footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Supporting types

private struct OnboardingPage {
    let systemImage: String
    let imageColor: Color
    let title: String
    let body: String
    let footnote: String?
    var bullets: [(String, String, String)] = []
}

// NSVisualEffectView wrapper
private struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.material = .hudWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Onboarding window manager

@MainActor
final class OnboardingWindowManager {
    private var window: NSWindow?

    func showIfNeeded(settings: AppSettings) {
        guard !settings.hasCompletedOnboarding else { return }
        show(settings: settings)
    }

    func show(settings: AppSettings) {
        let hostingController = NSHostingController(rootView: OnboardingView {
            // Mark complete and close window
            settings.hasCompletedOnboarding = true
            self.window?.close()
            self.window = nil
        })

        let win = NSWindow(contentViewController: hostingController)
        win.titlebarAppearsTransparent = true
        win.styleMask = [.titled, .fullSizeContentView, .closable]
        win.title = ""
        win.isMovableByWindowBackground = true
        win.center()
        win.isReleasedWhenClosed = false
        win.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }
}
