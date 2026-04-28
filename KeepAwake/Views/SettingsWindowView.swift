import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var controller: KeepAwakeController

    var body: some View {
        ZStack(alignment: .top) {
            KeepAwakeAmbientBackground()

            // App icon branding at top of settings window
            KeepAwakeBranding()
                .frame(width: 64, height: 64)
                .padding(.top, 12)
                .accessibilityHidden(true)
                .padding(.bottom, 8)

                Group {
                    switch controller.selectedTab {
                    case .settings:
                        SettingsTabView(
                            controller: controller,
                            settings: controller.settings
                        )
                    case .activationDuration:
                        ActivationDurationTabView(
                            controller: controller,
                            settings: controller.settings
                        )
                    case .about:
                        AboutTabView(controller: controller)
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: controller.selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // Bottom bar: status message + Quit button (hidden on About tab)
                if controller.selectedTab != .about {
                    HStack {
                        Text(controller.statusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(KeepAwakePalette.mutedInk)

                        Spacer()

                        Button(role: .destructive) {
                            // Do NOT call handleTermination() here — applicationWillTerminate
                            // owns all cleanup via terminateSync(). Calling both causes a
                            // double-teardown that releases the IOKit assertion twice.
                            NSApp.terminate(nil)
                        } label: {
                            Label("Quit", systemImage: "power")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.red.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .frame(minWidth: 620, minHeight: 520)
        .sheet(isPresented: $controller.isShowingAddDurationSheet) {
            AddDurationSheet { duration in
                controller.settings.addDuration(duration)
                controller.selectedDurationID = duration.id
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(KeepAwakePalette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(KeepAwakePalette.border, lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func tabButton(for tab: AppTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                controller.selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))

                Text(tab.title)
                    .font(.system(size: 13, weight: controller.selectedTab == tab ? .semibold : .medium))
            }
            .foregroundStyle(controller.selectedTab == tab ? Color.white : KeepAwakePalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if controller.selectedTab == tab {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(KeepAwakePalette.blue)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.\(tab.rawValue)")
    }
}
