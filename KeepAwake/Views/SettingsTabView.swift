import AppKit
import SwiftUI

struct SettingsTabView: View {
    @ObservedObject var controller: KeepAwakeController
    @ObservedObject var settings: AppSettings
    let quitApp: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                KeepAwakePanel {
                    Text("General Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)

                    settingsToggle(
                        title: "Start at Login",
                        detail: "Launch KeepAwake automatically when you sign in.",
                        isOn: Binding(
                            get: { controller.startAtLoginEnabled },
                            set: { controller.startAtLoginEnabled = $0 }
                        ),
                        identifier: "settings.startAtLogin"
                    )

                    settingsToggle(
                        title: "Activate on Launch",
                        detail: "Begin the saved default duration as soon as KeepAwake launches.",
                        isOn: $settings.activateOnLaunch,
                        identifier: "settings.activateOnLaunch"
                    )
                }

                KeepAwakePanel {
                    Text("Battery Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)

                    settingsToggle(
                        title: "Deactivate Below Battery Threshold",
                        detail: "Stop the active session automatically once the battery drops under the chosen level.",
                        isOn: $settings.deactivateBelowThreshold,
                        identifier: "settings.deactivateBelowThreshold"
                    )

                    if settings.deactivateBelowThreshold {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Threshold")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(KeepAwakePalette.ink)
                                Spacer()
                                Text("\(settings.batteryThreshold)%")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(KeepAwakePalette.ink)
                            }

                            BatteryThresholdSlider(value: $settings.batteryThreshold)
                                .frame(height: 24)

                            HStack {
                                ForEach(AppSettings.thresholdStops, id: \.self) { value in
                                    Text("\(value)%")
                                        .font(.system(size: 11))
                                        .foregroundStyle(KeepAwakePalette.mutedInk)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(.leading, 26)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    settingsToggle(
                        title: "Deactivate in Low Power Mode",
                        detail: "Stop the active session when Low Power Mode turns on.",
                        isOn: $settings.deactivateOnLowPowerMode,
                        identifier: "settings.lowPowerMode"
                    )
                }

                KeepAwakePanel {
                    Text("Display")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)

                    settingsToggle(
                        title: "Allow Display Sleep",
                        detail: "Keep the Mac awake while still letting the display sleep normally.",
                        isOn: $settings.allowDisplaySleep,
                        identifier: "settings.allowDisplaySleep"
                    )
                }

                HStack {
                    Spacer()

                    Button(role: .destructive, action: quitApp) {
                        Label("Quit App", systemImage: "power")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 6)
            }
            .padding(.bottom, 8)
        }
        .animation(.easeInOut(duration: 0.18), value: settings.deactivateBelowThreshold)
    }

    private func settingsToggle(
        title: String,
        detail: String,
        isOn: Binding<Bool>,
        identifier: String
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KeepAwakePalette.ink)

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(KeepAwakePalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.checkbox)
        .accessibilityIdentifier(identifier)
    }
}

private struct BatteryThresholdSlider: NSViewRepresentable {
    @Binding var value: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(
            value: Double(index(for: value)),
            minValue: 0,
            maxValue: Double(AppSettings.thresholdStops.count - 1),
            target: context.coordinator,
            action: #selector(Coordinator.sliderChanged(_:))
        )
        slider.numberOfTickMarks = AppSettings.thresholdStops.count
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = true
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        let index = Double(index(for: value))
        if nsView.doubleValue != index {
            nsView.doubleValue = index
        }
    }

    private func index(for threshold: Int) -> Int {
        AppSettings.thresholdStops.firstIndex(of: AppSettings.snapThreshold(threshold)) ?? 1
    }

    @MainActor
    final class Coordinator: NSObject {
        @Binding private var value: Int

        init(value: Binding<Int>) {
            _value = value
        }

        @objc
        func sliderChanged(_ sender: NSSlider) {
            let index = min(max(Int(sender.doubleValue.rounded()), 0), AppSettings.thresholdStops.count - 1)
            value = AppSettings.thresholdStops[index]
        }
    }
}
