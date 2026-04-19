import AppKit
import SwiftUI

struct AboutTabView: View {
    @ObservedObject var controller: KeepAwakeController

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                KeepAwakeBrandMark(size: 80)

                VStack(spacing: 4) {
                    Text("KeepAwake")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(KeepAwakePalette.ink)

                    Text("Version \(appVersion)")
                        .font(.system(size: 13))
                        .foregroundStyle(KeepAwakePalette.mutedInk)
                }

                Text("Keep your Mac and display awake for the duration you choose, with menu bar controls built for quick toggling.")
                    .font(.system(size: 13))
                    .foregroundStyle(KeepAwakePalette.mutedInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                HStack(spacing: 12) {
                    linkButton(
                        title: "GitHub",
                        icon: "chevron.left.forwardslash.chevron.right",
                        identifier: "about.repo"
                    ) {
                        controller.open(.repository)
                    }

                    linkButton(
                        title: "Donate",
                        icon: "cup.and.saucer.fill",
                        identifier: "about.donate"
                    ) {
                        controller.open(.donation)
                    }
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Button {
                    controller.open(.profile)
                } label: {
                    Text("Made by Adham Haitham")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(KeepAwakePalette.blue)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("about.profile")

                Text("Built with Swift & SwiftUI")
                    .font(.system(size: 11))
                    .foregroundStyle(KeepAwakePalette.mutedInk.opacity(0.6))
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private func linkButton(
        title: String,
        icon: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(KeepAwakePalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(KeepAwakePalette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(KeepAwakePalette.border, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
