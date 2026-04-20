import SwiftUI

/// The quick-access duration buttons shown in the menu bar popover.
///
/// Rules:
/// • Always shows the 3 fixed quick durations (15m, 1h, ∞).
/// • If the user's default duration is one of those 3, it gets a distinct
///   "default" style (accent border + tinted label) — only 3 buttons shown.
/// • If the default duration is something else (e.g. 30m, 2h …), a 4th button
///   is added on the right showing that custom default.
struct QuickActionsMenuView: View {
    let quickDurations: [ActivationDuration]
    let defaultDurationID: String
    let activate: (ActivationDuration) -> Void

    /// The default duration if it is NOT one of the 3 fixed quick ones.
    private var extraDefault: ActivationDuration? {
        let quickIDs = Set(quickDurations.map(\.id))
        guard !quickIDs.contains(defaultDurationID) else { return nil }
        // Reconstruct it by looking in defaultDurations (or use the ID directly)
        return ActivationDuration.defaultDurations.first { $0.id == defaultDurationID }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(quickDurations) { duration in
                quickButton(for: duration)
            }

            if let extra = extraDefault {
                quickButton(for: extra, forcedTitle: extra.menuTitle)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // Transparent — inherits the menu window's material
        .background(Color.clear)
    }

    // MARK: - Button

    private func quickButton(
        for duration: ActivationDuration,
        forcedTitle: String? = nil
    ) -> some View {
        let isDefault = duration.id == defaultDurationID
        let title = forcedTitle ?? shortTitle(for: duration)

        return Button {
            activate(duration)
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(
                        size: duration.isIndefinite ? 22 : 16,
                        weight: .semibold,
                        design: duration.isIndefinite ? .rounded : .default
                    ))
                    .foregroundStyle(isDefault ? Color.accentColor : Color.primary)
                    .frame(maxWidth: .infinity)

                // Tiny "default" dot under the label
                if isDefault {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 54, height: isDefault ? 60 : 58)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isDefault
                        ? Color.accentColor.opacity(0.12)
                        : Color.primary.opacity(0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isDefault ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.12),
                                lineWidth: isDefault ? 1.5 : 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private func shortTitle(for duration: ActivationDuration) -> String {
        if duration.isIndefinite { return "∞" }
        let s = duration.totalSeconds
        if s % 3600 == 0 { return "\(s / 3600)h" }
        if s % 60 == 0 { return "\(s / 60)m" }
        return duration.menuTitle
    }
}
