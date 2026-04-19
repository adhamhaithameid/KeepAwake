import AppKit
import SwiftUI

struct KeepAwakeAmbientBackground: View {
    var body: some View {
        KeepAwakePalette.windowBackground.ignoresSafeArea()
    }
}

struct KeepAwakePanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(KeepAwakePalette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(KeepAwakePalette.border, lineWidth: 1)
                }
        }
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

struct KeepAwakeActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 60)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.88 : 1))
            }
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
