import SwiftUI

struct ActivationDurationTabView: View {
    @ObservedObject var controller: KeepAwakeController
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            KeepAwakePanel {
                Text("Activation Options")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KeepAwakePalette.ink)

                Text("Choose which durations appear in the menu bar app and set the default duration used for left-click activation.")
                    .font(.system(size: 13))
                    .foregroundStyle(KeepAwakePalette.mutedInk)

                List(selection: $controller.selectedDurationID) {
                    ForEach(settings.availableDurations) { duration in
                        HStack {
                            Text(duration.menuTitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(KeepAwakePalette.ink)

                            Spacer()

                            if settings.defaultDurationID == duration.id {
                                Text("Default")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(KeepAwakePalette.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(KeepAwakePalette.blue.opacity(0.12), in: Capsule())
                            }
                        }
                        .tag(Optional(duration.id))
                    }
                }
                .frame(minHeight: 260)
                .scrollContentBackground(.hidden)
                .background(KeepAwakePalette.surfaceWarm, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(KeepAwakePalette.border, lineWidth: 1)
                }
            }

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

                Button("Reset Options") {
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
    }

    private var selectedDuration: ActivationDuration? {
        guard let selectedID = controller.selectedDurationID else { return nil }
        return settings.availableDurations.first(where: { $0.id == selectedID })
    }

    private var canRemoveSelection: Bool {
        guard let selectedDuration else { return false }
        return !selectedDuration.isIndefinite
    }

    private var canSetSelectionAsDefault: Bool {
        guard let selectedID = controller.selectedDurationID else { return false }
        return settings.defaultDurationID != selectedID
    }

    private func removeSelectedDuration() {
        guard let selectedID = controller.selectedDurationID else { return }
        settings.removeDuration(id: selectedID)
        controller.selectedDurationID = settings.defaultDurationID
    }

    private func setSelectionAsDefault() {
        guard let selectedID = controller.selectedDurationID else { return }
        settings.setDefaultDuration(selectedID)
    }
}
