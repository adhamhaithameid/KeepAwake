import SwiftUI

struct ActivationDurationTabView: View {
    @ObservedObject var controller: KeepAwakeController
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // ── Duration list ────────────────────────────────────────────
            KeepAwakePanel {
                HStack(alignment: .center) {
                    Text("Durations")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeepAwakePalette.ink)

                    Spacer()

                    // Pin usage indicator
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(i < settings.pinnedDurationIDs.count
                                      ? Color.accentColor
                                      : Color.secondary.opacity(0.2))
                                .frame(width: 14, height: 4)
                        }
                        Text("pins")
                            .font(.system(size: 10))
                            .foregroundStyle(KeepAwakePalette.mutedInk)
                    }
                    .animation(.easeInOut(duration: 0.2), value: settings.pinnedDurationIDs.count)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(settings.availableDurations) { duration in
                            durationRow(duration)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: .infinity)
                .background(KeepAwakePalette.surfaceWarm,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(KeepAwakePalette.border, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Toolbar ──────────────────────────────────────────────────
            HStack(spacing: 10) {
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

                Button("Reset") {
                    settings.resetDurations()
                    controller.selectedDurationID = settings.defaultDurationID
                }
                .buttonStyle(.bordered)

                Button("Set Default") {
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
        let isDefault  = settings.defaultDurationID == duration.id
        let isPinned   = settings.isPinned(duration.id)
        let isLast     = duration.id == settings.availableDurations.last?.id

        return Button {
            controller.selectedDurationID = duration.id
        } label: {
            HStack(spacing: 10) {
                // Selection tick
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(isSelected ? Color.accentColor : KeepAwakePalette.border)
                    .frame(width: 20)

                Text(duration.menuTitle)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(KeepAwakePalette.ink)

                Spacer()

                // Badges
                HStack(spacing: 6) {
                    if isDefault {
                        Text("Default")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(KeepAwakePalette.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(KeepAwakePalette.blue.opacity(0.12), in: Capsule())
                    }

                    // Pin toggle — tappable independently
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            settings.togglePin(duration.id)
                        }
                    } label: {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isPinned ? Color.accentColor : KeepAwakePalette.mutedInk)
                            .frame(width: 26, height: 26)
                            .background(
                                isPinned ? Color.accentColor.opacity(0.1) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(isPinned ? "Unpin from menu bar" : "Pin to menu bar (max 3)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.07) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(KeepAwakePalette.border.opacity(0.45))
                    .frame(height: 0.5)
                    .padding(.leading, 42)
            }
        }
    }

    // MARK: - Logic

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
