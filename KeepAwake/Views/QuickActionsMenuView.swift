import SwiftUI

/// Quick-access duration buttons in the menu bar popover.
///
/// Rules:
/// • Shows the 3 pinned durations.
/// • If the default duration is NOT one of the pinned ones, a 4th button appears.
/// • The default button is highlighted with an accent border + tinted fill.
/// • Each button has a spring "bounce" press animation via BounceButtonStyle.
struct QuickActionsMenuView: View {
    let quickDurations: [ActivationDuration]
    let defaultDurationID: String
    let activate: (ActivationDuration) -> Void

    /// Extra default button — only when the default isn't already in quick slots.
    private var extraDefault: ActivationDuration? {
        let quickIDs = Set(quickDurations.map(\.id))
        guard !quickIDs.contains(defaultDurationID) else { return nil }
        return ActivationDuration.defaultDurations.first { $0.id == defaultDurationID }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(quickDurations) { duration in
                quickButton(for: duration)
            }
            if let extra = extraDefault {
                quickButton(for: extra)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.clear)
    }

    // MARK: - Button

    private func quickButton(for duration: ActivationDuration) -> some View {
        let isDefault = duration.id == defaultDurationID
        let title = shortTitle(for: duration)
        let a11yLabel = isDefault
            ? "\(duration.menuTitle), default duration"
            : duration.menuTitle

        return Button {
            activate(duration)
        } label: {
            Text(title)
                .font(.system(
                    size: duration.isIndefinite ? 22 : 16,
                    weight: .semibold,
                    design: duration.isIndefinite ? .rounded : .default
                ))
                .foregroundStyle(isDefault ? Color.accentColor : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(width: 54, height: 58)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isDefault
                            ? Color.accentColor.opacity(0.12)
                            : Color.primary.opacity(0.07))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    isDefault ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.12),
                                    lineWidth: isDefault ? 2 : 1
                                )
                        }
                }
        }
        // Spring bounce — 1.0 → 0.88 → 1.0 with a springy overshoot
        .buttonStyle(BounceButtonStyle())
        .accessibilityLabel(a11yLabel)
        .accessibilityHint("Activate a KeepAwake session for \(duration.menuTitle)")
    }

    private func shortTitle(for duration: ActivationDuration) -> String {
        if duration.isIndefinite { return "∞" }
        let s = duration.totalSeconds
        if s % 3600 == 0 { return "\(s / 3600)h" }
        if s % 60 == 0 { return "\(s / 60)m" }
        return duration.menuTitle
    }
}

// MARK: - BounceButtonStyle

/// A ButtonStyle that scales down to 0.88 on press and springs back with
/// a slight overshoot — giving the button a satisfying tactile "bounce".
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(
                configuration.isPressed
                    ? .easeIn(duration: 0.08)
                    : .spring(response: 0.35, dampingFraction: 0.55),
                value: configuration.isPressed
            )
    }
}
