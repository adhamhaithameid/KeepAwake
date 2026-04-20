import AppKit
import SwiftUI

struct SettingsTabView: View {
    @ObservedObject var controller: KeepAwakeController
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                KeepAwakePanel {
                    Text("General Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)

                    clickableToggleRow(
                        title: "Start at Login",
                        detail: "Launch KeepAwake automatically when you sign in.",
                        isOn: Binding(
                            get: { controller.startAtLoginEnabled },
                            set: { controller.startAtLoginEnabled = $0 }
                        ),
                        identifier: "settings.startAtLogin"
                    )

                    clickableToggleRow(
                        title: "Activate on Launch",
                        detail: "Begin the saved default duration as soon as KeepAwake launches.",
                        isOn: $settings.activateOnLaunch,
                        identifier: "settings.activateOnLaunch"
                    )

                    clickableToggleRow(
                        title: "Show Countdown in Menu Bar",
                        detail: "Display a live glanceable label (e.g. ☕ 42m) next to the icon while a session is active.",
                        isOn: $settings.showStatusLabel,
                        identifier: "settings.showStatusLabel"
                    )
                }

                KeepAwakePanel {
                    Text("Battery Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)

                    clickableToggleRow(
                        title: "Deactivate Below Battery Threshold",
                        detail: "Stop the active session automatically once battery drops under the set level.",
                        isOn: $settings.deactivateBelowThreshold,
                        identifier: "settings.deactivateBelowThreshold"
                    )

                    if settings.deactivateBelowThreshold {
                        BatteryThresholdControl(threshold: $settings.batteryThreshold)
                            .padding(.leading, 26)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    clickableToggleRow(
                        title: "Deactivate in Low Power Mode",
                        detail: "Stop any active session the moment Low Power Mode turns on.",
                        isOn: $settings.deactivateOnLowPowerMode,
                        identifier: "settings.lowPowerMode"
                    )
                }

                KeepAwakePanel {
                    Text("Display")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)

                 clickableToggleRow(
                        title: "Allow Display Sleep",
                        detail: "Keep the Mac awake while still letting the display sleep normally.",
                        isOn: $settings.allowDisplaySleep,
                        identifier: "settings.allowDisplaySleep"
                    )
                }

                KeepAwakePanel {
                    Text("Automation")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)

                    clickableToggleRow(
                        title: "Activate When Focus Mode Is On",
                        detail: "Automatically start the default duration when macOS Focus (Do Not Disturb) turns on.",
                        isOn: $settings.autoActivateOnFocus,
                        identifier: "settings.autoActivateOnFocus"
                    )

                    if settings.autoActivateOnFocus {
                        clickableToggleRow(
                            title: "Deactivate When Focus Mode Ends",
                            detail: "Stop the session automatically when Focus Mode turns off (only if KeepAwake started it).",
                            isOn: $settings.deactivateWhenFocusEnds,
                            identifier: "settings.deactivateWhenFocusEnds"
                        )
                        .padding(.leading, 26)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    clickableToggleRow(
                        title: "Activate When Screen Sharing",
                        detail: "Automatically start the default duration when Screen Sharing (or AirPlay) begins.",
                        isOn: $settings.autoActivateOnScreenSharing,
                        identifier: "settings.autoActivateOnScreenSharing"
                    )
                }
            }
            .padding(.bottom, 8)
        }
        .animation(.easeInOut(duration: 0.18), value: settings.deactivateBelowThreshold)
        .animation(.easeInOut(duration: 0.18), value: settings.autoActivateOnFocus)
    }


    // MARK: - Fully-clickable toggle row

    /// The entire row is a Button that toggles `isOn`. The `Toggle` inside
    /// has `allowsHitTesting(false)` so all clicks route through the outer button.
    private func clickableToggleRow(
        title: String,
        detail: String,
        isOn: Binding<Bool>,
        identifier: String
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Toggle("", isOn: isOn)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .allowsHitTesting(false)  // Outer button handles the tap

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)

                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(KeepAwakePalette.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Battery threshold control

/// A continuous NSSlider (1–100 %) with magnetic snap points at the
/// predefined stops (10, 20, 50, 70, 90). The slider animates to the
/// nearest snap point when within ±4 %, but any value is valid.
private struct BatteryThresholdControl: View {
    @Binding var threshold: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Value readout
            HStack {
                Text("Deactivate below")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KeepAwakePalette.ink)
                Spacer()
                Text("\(threshold)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(thresholdColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.1), value: threshold)
            }

            // Magnetic continuous slider
            MagneticBatterySlider(value: $threshold)
                .frame(height: 24)

            // Snap-point labels beneath the slider
            GeometryReader { geo in
                let snapPoints = AppSettings.batterySnapPoints
                let total = Double(AppSettings.batteryRange.upperBound - AppSettings.batteryRange.lowerBound)
                ForEach(snapPoints, id: \.self) { stop in
                    let fraction = Double(stop - AppSettings.batteryRange.lowerBound) / total
                    Text("\(stop)%")
                        .font(.system(size: 9))
                        .foregroundStyle(threshold == stop
                            ? Color.accentColor
                            : KeepAwakePalette.mutedInk.opacity(0.7))
                        .position(
                            x: fraction * geo.size.width,
                            y: geo.size.height / 2
                        )
                        .animation(.easeOut(duration: 0.1), value: threshold)
                }
            }
            .frame(height: 14)
        }
    }

    private var thresholdColor: Color {
        switch threshold {
        case ..<21: return .red
        case 21..<51: return KeepAwakePalette.orange
        default: return .green
        }
    }
}

// MARK: - NSSlider wrapper with magnetic behaviour

private struct MagneticBatterySlider: NSViewRepresentable {
    @Binding var value: Int

    func makeCoordinator() -> Coordinator { Coordinator(value: $value) }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider()
        slider.minValue = Double(AppSettings.batteryRange.lowerBound)
        slider.maxValue = Double(AppSettings.batteryRange.upperBound)
        slider.doubleValue = Double(value)
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.sliderChanged(_:))
        slider.isContinuous = true
        // Remove discrete tick marks — slider is now free-range.
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false
        slider.sliderType = .linear
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        // Only update the slider if not currently dragging (to avoid fighting).
        if !context.coordinator.isDragging {
            nsView.doubleValue = Double(value)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        @Binding var value: Int
        var isDragging = false

        init(value: Binding<Int>) { _value = value }

        @objc func sliderChanged(_ sender: NSSlider) {
            isDragging = true
            let rawValue = Int(sender.doubleValue.rounded())
            let snapped = AppSettings.applyMagneticSnap(rawValue)

            if snapped != rawValue {
                // Move the thumb visually to the snap point.
                sender.doubleValue = Double(snapped)
            }
            value = snapped
            isDragging = false
        }
    }
}
