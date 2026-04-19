import AppKit
import SwiftUI

enum KeepAwakePalette {
    static let ink = Color.primary
    static let mutedInk = Color.secondary
    static let blue = Color.accentColor
    static let orange = Color(red: 0.92, green: 0.47, blue: 0.16)
    static let success = Color(red: 0.17, green: 0.60, blue: 0.38)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let surfaceWarm = Color(nsColor: .underPageBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.65)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
}

struct KeepAwakeAmbientBackground: View {
    var body: some View {
        KeepAwakePalette.windowBackground
            .ignoresSafeArea()
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
    }
}

struct KeepAwakeBrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.95),
                            Color.accentColor.opacity(0.75),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("KA")
                .font(.system(size: size * 0.33, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

struct KeepAwakeBranding: View {
    var body: some View {
        KeepAwakeBrandMark()
    }
}
