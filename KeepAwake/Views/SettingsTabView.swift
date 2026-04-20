import AppKit
import SwiftUI

struct SettingsTabView: View {
    @ObservedObject var controller: KeepAwakeController
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // MARK: General

                KeepAwakePanel {
                    Text("General Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)
                        .accessibilityAddTraits(.isHeader)

                    clickableToggleRow(
                        title: "Start at Login",
                        detail: "Launch KeepAwake automatically when you sign in.",
                        hint: "When enabled, KeepAwake appears in the menu bar every time you log in.",
                        isOn: Binding(
                            get: { controller.startAtLoginEnabled },
                            set: { controller.startAtLoginEnabled = $0 }
                        ),
                        identifier: "settings.startAtLogin"
                    )

                    clickableToggleRow(
                        title: "Activate on Launch",
                        detail: "Begin the saved default duration as soon as KeepAwake launches.",
                        hint: "Automatically starts a session using your default duration at app launch.",
                        isOn: $settings.activateOnLaunch,
                        identifier: "settings.activateOnLaunch"
                    )

                    clickableToggleRow(
                        title: "Show Countdown in Menu Bar",
                        detail: "Display a live glanceable label (e.g. ☕ 42m) next to the icon while a session is active.",
                        hint: "Shows a live time countdown in the menu bar so you can see the remaining session time at a glance.",
                        isOn: $settings.showStatusLabel,
                        identifier: "settings.showStatusLabel"
                    )
                }

                // MARK: Battery

                KeepAwakePanel {
                    Text("Battery Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)
                        .accessibilityAddTraits(.isHeader)

                    clickableToggleRow(
                        title: "Deactivate Below Battery Threshold",
                        detail: "Stop the active session automatically once battery drops under the set level.",
                        hint: "Protects battery life by ending a session when charge falls below your chosen percentage.",
                        isOn: $settings.deactivateBelowThreshold,
                        identifier: "settings.deactivateBelowThreshold"
                    )

                    if settings.deactivateBelowThreshold {
                        BatteryThresholdControl(threshold: $settings.batteryThreshold)
                            .padding(.leading, 26)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .accessibilityLabel("Battery threshold slider, current value \(settings.batteryThreshold) percent")
                            .accessibilityHint("Drag to set the battery percentage at which the session stops. Snaps to common values.")
                    }

                    clickableToggleRow(
                        title: "Deactivate in Low Power Mode",
                        detail: "Stop any active session the moment Low Power Mode turns on.",
                        hint: "When macOS Low Power Mode activates, any running KeepAwake session is stopped immediately.",
                        isOn: $settings.deactivateOnLowPowerMode,
                        identifier: "settings.lowPowerMode"
                    )
                }

                // MARK: Display & Sleep

                KeepAwakePanel {
                    Text("Display & Sleep")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)
                        .accessibilityAddTraits(.isHeader)

                    clickableToggleRow(
                        title: "Allow Display Sleep",
                        detail: "Keep the Mac awake while still letting the display sleep normally.",
                        hint: "The Mac stays active for background tasks, but the screen can dim and turn off.",
                        isOn: $settings.allowDisplaySleep,
                        identifier: "settings.allowDisplaySleep"
                    )

                    clickableToggleRow(
                        title: "Allow Power Nap",
                        detail: "Let Time Machine, push email, and background syncs run during your session.",
                        hint: "Uses a lighter IOKit assertion that allows Power Nap — background activity like Time Machine and iCloud sync can still run while the session is active. When off, a stricter assertion blocks all idle activity.",
                        isOn: $settings.allowPowerNap,
                        identifier: "settings.allowPowerNap"
                    )
                }

                // MARK: Automation

                KeepAwakePanel {
                    Text("Automation")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)
                        .accessibilityAddTraits(.isHeader)

                    clickableToggleRow(
                        title: "Activate When Focus Mode Is On",
                        detail: "Automatically start the default duration when macOS Focus (Do Not Disturb) turns on.",
                        hint: "KeepAwake starts a session automatically whenever you enable Focus Mode or Do Not Disturb.",
                        isOn: $settings.autoActivateOnFocus,
                        identifier: "settings.autoActivateOnFocus"
                    )

                    if settings.autoActivateOnFocus {
                        clickableToggleRow(
                            title: "Deactivate When Focus Mode Ends",
                            detail: "Stop the session automatically when Focus Mode turns off (only if KeepAwake started it).",
                            hint: "Only applies to sessions that were started automatically by Focus Mode. Manually started sessions are not affected.",
                            isOn: $settings.deactivateWhenFocusEnds,
                            identifier: "settings.deactivateWhenFocusEnds"
                        )
                        .padding(.leading, 26)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    clickableToggleRow(
                        title: "Activate When Screen Sharing",
                        detail: "Automatically start the default duration when Screen Sharing (or AirPlay) begins.",
                        hint: "Prevents your Mac from sleeping mid-presentation or during a screen share session.",
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

    /// The entire row is a `Button` that toggles `isOn`. The `Toggle` inside
    /// has `allowsHitTesting(false)` so all taps route through the outer button.
    /// The `hint` parameter is surfaced to VoiceOver as an `accessibilityHint`.
    private func clickableToggleRow(
        title: String,
        detail: String,
        hint: String = "",
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
        // Combine the entire row into one VoiceOver element labelled by title + state.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(isOn.wrappedValue ? "on" : "off")")
        .accessibilityHint(hint.isEmpty ? detail : hint)
        .accessibilityAddTraits(.isButton)
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
                    .accessibilityLabel("\(threshold) percent")
            }

            // Magnetic continuous slider
            MagneticBatterySlider(value: $threshold)
                .frame(height: 24)
                .accessibilityLabel("Battery threshold")
                .accessibilityValue("\(threshold) percent")
                .accessibilityHint("Drag left or right to set the battery level at which the session stops")

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
                        .accessibilityHidden(true)  // Slider value label covers this
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
        // Remove discrete tick marks — slider is now free-range with magnetic snapping.
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false
        slider.sliderType = .linear
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        // Only update the slider if not currently dragging (to avoid fighting the user).
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
