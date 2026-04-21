import AppKit
import SwiftUI

// MARK: - Palette

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

// MARK: - Ambient background

struct KeepAwakeAmbientBackground: View {
    var body: some View {
        KeepAwakePalette.windowBackground
            .ignoresSafeArea()
    }
}

// MARK: - Panel container

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

// MARK: - Brand mark

/// Shows the actual app icon (brand-mark.png, bundled in Resources/).
///
/// `brand-mark.png` is a loose bundle resource, not an asset catalog entry,
/// so it is loaded via `Bundle.main.url(forResource:withExtension:)`.
/// If the file is unavailable (e.g. during Swift Previews without a full
/// bundle), the view falls back to an SF Symbol cup on a dark background.
struct KeepAwakeBrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "brand-mark", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                // Real icon — already carries the macOS rounded-square shape.
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                // Fallback for environments where the bundle is incomplete.
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.10, green: 0.13, blue: 0.22),
                                    Color(red: 0.08, green: 0.10, blue: 0.18),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: size * 0.45, weight: .medium))
                        .foregroundStyle(Color(red: 0.31, green: 0.76, blue: 0.97))
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.20), radius: 12, y: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Convenience wrapper

struct KeepAwakeBranding: View {
    var body: some View {
        KeepAwakeBrandMark()
    }
}
