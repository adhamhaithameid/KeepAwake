import SwiftUI

struct ActivationDurationTabView: View {
    @ObservedObject var controller: KeepAwakeController
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // ── Duration list ─────────────────────────────────────────────
            KeepAwakePanel {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Activation Options")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(KeepAwakePalette.ink)
                        Text("Tap a row to select it. Use the 📌 button to pin a duration as a quick-access button in the menu bar (max 3 pins).")
                            .font(.system(size: 12))
                            .foregroundStyle(KeepAwakePalette.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    // Pin legend
                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentColor)
                        Text("Pinned to menu")
                            .font(.system(size: 11))
                            .foregroundStyle(KeepAwakePalette.mutedInk)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.08),
                                in: Capsule())
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(settings.availableDurations) { duration in
                            durationRow(duration)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 160, maxHeight: .infinity)
                .background(KeepAwakePalette.surfaceWarm,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(KeepAwakePalette.border, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Pin count hint ────────────────────────────────────────────
            let pinCount = settings.pinnedDurationIDs.count
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(i < pinCount ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(width: 18, height: 4)
                }
                Text(pinCount == 3 ? "3/3 pins used" : "\(pinCount)/3 pins used")
                    .font(.system(size: 11))
                    .foregroundStyle(pinCount == 3 ? Color.accentColor : KeepAwakePalette.mutedInk)
            }
            .animation(.easeInOut(duration: 0.2), value: pinCount)

            // ── Toolbar ───────────────────────────────────────────────────
            HStack(spacing: 12) {
                Button {
                    controller.isShowingAddDurationSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button {
                    removeSelectedDuration()
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .buttonStyle(.bordered)
                .disabled(!canRemoveSelection)

                Spacer()

                Button("Reset to Defaults") {
                    settings.resetDurations()
                    controller.selectedDurationID = settings.defaultDurationID
                }
                .buttonStyle(.bordered)

                Button("Set as Default") {
                    setSelectionAsDefault()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSetSelectionAsDefault)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Row

    private func durationRow(_ duration: ActivationDuration) -> some View {
        let isSelected = controller.selectedDurationID == duration.id
        let isDefault = settings.defaultDurationID == duration.id
        let isPinned = settings.isPinned(duration.id)

        return Button {
            // Tap anywhere on the row to select it
            controller.selectedDurationID = duration.id
        } label: {
            HStack(spacing: 10) {
                // Selection tick
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : KeepAwakePalette.border)
                    .frame(width: 20)

                // Duration label
                Text(duration.menuTitle)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(KeepAwakePalette.ink)

                Spacer()

                // "Default" badge
                if isDefault {
                    Text("Default")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(KeepAwakePalette.blue.opacity(0.12), in: Capsule())
                }

                // Pin / Unpin button — tappable independently from the row
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        settings.togglePin(duration.id)
                    }
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isPinned ? Color.accentColor : KeepAwakePalette.mutedInk)
                        .frame(width: 28, height: 28)
                        .background(isPinned ? Color.accentColor.opacity(0.1) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(isPinned
                      ? "Remove from quick-access buttons"
                      : "Pin as quick-access button in menu bar")
                .animation(.easeInOut(duration: 0.15), value: isPinned)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? Color.accentColor.opacity(0.07) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Row separator
        .overlay(alignment: .bottom) {
            if duration.id != settings.availableDurations.last?.id {
                Rectangle()
                    .fill(KeepAwakePalette.border.opacity(0.5))
                    .frame(height: 0.5)
                    .padding(.leading, 42)
            }
        }
    }

    // MARK: - Logic helpers

    private var canRemoveSelection: Bool {
        guard let id = controller.selectedDurationID,
              let d = settings.availableDurations.first(where: { $0.id == id }) else { return false }
        return !d.isIndefinite
    }

    private var canSetSelectionAsDefault: Bool {
        guard let id = controller.selectedDurationID else { return false }
        return settings.defaultDurationID != id
    }

    private func removeSelectedDuration() {
        guard let id = controller.selectedDurationID else { return }
        settings.removeDuration(id: id)
        controller.selectedDurationID = settings.defaultDurationID
    }

    private func setSelectionAsDefault() {
        guard let id = controller.selectedDurationID else { return }
        settings.setDefaultDuration(id)
    }
}
