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

/// Shows the actual app icon / brand mark.
///
/// ## Loading strategy (in priority order):
/// 1. **Asset catalog** — `NSImage(named: "AppIcon")` is always available in a
///    built app because Xcode compiles the `AppIcon.appiconset` into the bundle.
///    This is the most reliable path and works in both the main app and
///    SwiftUI Previews with a compiled bundle.
/// 2. **Loose bundle resource** — `brand-mark.png` copied by the "Copy App Resources"
///    build script. Covers edge cases where the asset catalog entry isn't named "AppIcon".
/// 3. **SF Symbol fallback** — always available; used only when neither of the
///    above paths produces an image (e.g. unit test host without resources).
struct KeepAwakeBrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let img = loadBrandImage() {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(
                        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    )
            } else {
                // Fallback for environments where no bundle resources are available.
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.44, green: 0.65, blue: 0.82),
                                    Color(red: 0.36, green: 0.57, blue: 0.74),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: size * 0.45, weight: .medium))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.20), radius: 12, y: 6)
        .accessibilityHidden(true)
    }

    /// Tries all known loading paths in order.
    private func loadBrandImage() -> NSImage? {
        // 1. Asset catalog (AppIcon — always compiled into the bundle)
        if let img = NSImage(named: "AppIcon") { return img }
        // 2. Loose bundle resource (brand-mark.png)
        if let url = Bundle.main.url(forResource: "brand-mark", withExtension: "png"),
           let img = NSImage(contentsOf: url) { return img }
        return nil
    }
}


// MARK: - Convenience wrapper

struct KeepAwakeBranding: View {
    var body: some View {
        KeepAwakeBrandMark()
    }
}
