import SwiftUI

struct QuickActionsMenuView: View {
    let activate: (ActivationDuration) -> Void

    var body: some View {
        HStack(spacing: 10) {
            quickActionButton(for: .minutes(15), title: "15m")
            quickActionButton(for: .hours(1), title: "1h")
            quickActionButton(for: .indefinite, title: "∞", isInfinity: true)
        }
        .padding(12)
        .frame(width: 228)
        .background(KeepAwakePalette.surface)
    }

    private func quickActionButton(
        for duration: ActivationDuration,
        title: String,
        isInfinity: Bool = false
    ) -> some View {
        Button {
            activate(duration)
        } label: {
            Text(title)
                .font(.system(
                    size: isInfinity ? 24 : 17,
                    weight: .semibold,
                    design: isInfinity ? .rounded : .default
                ))
                .foregroundStyle(KeepAwakePalette.ink)
                .frame(width: 58, height: 54)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(KeepAwakePalette.surfaceWarm)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(KeepAwakePalette.border, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }
}
