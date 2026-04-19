import SwiftUI

struct AddDurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    let onAdd: (ActivationDuration) -> Void

    @State private var hoursText = "0"
    @State private var minutesText = "0"
    @State private var secondsText = "0"

    private enum Field {
        case hours
        case minutes
        case seconds
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                durationField(
                    title: "Hours",
                    text: $hoursText,
                    field: .hours
                )

                durationField(
                    title: "Minutes",
                    text: $minutesText,
                    field: .minutes
                )

                durationField(
                    title: "Seconds",
                    text: $secondsText,
                    field: .seconds
                )
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add Duration") {
                    onAdd(
                        ActivationDuration(
                            hours: hoursValue,
                            minutes: minutesValue,
                            seconds: secondsValue
                        )
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(totalSeconds == 0)
            }
        }
        .padding(24)
        .frame(width: 580)
        .onAppear {
            focusedField = .hours
        }
    }

    private var hoursValue: Int {
        sanitize(hoursText, upperBound: 999)
    }

    private var minutesValue: Int {
        sanitize(minutesText, upperBound: 59)
    }

    private var secondsValue: Int {
        sanitize(secondsText, upperBound: 59)
    }

    private var totalSeconds: Int {
        (hoursValue * 3600) + (minutesValue * 60) + secondsValue
    }

    private func durationField(
        title: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(KeepAwakePalette.ink)

            TextField("0", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .focused($focusedField, equals: field)
                .onChange(of: text.wrappedValue) { newValue in
                    text.wrappedValue = filtered(newValue)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func filtered(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        return digits.isEmpty ? "0" : String(digits.prefix(3))
    }

    private func sanitize(_ value: String, upperBound: Int) -> Int {
        min(Int(value) ?? 0, upperBound)
    }
}
