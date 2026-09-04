import SwiftUI
import WSPTCore

/// The add-task form: task name, estimated minutes, importance picker.
/// Mirrors the `.panel` form in docs/wspt-todo.html (lines 261-286),
/// including its validation messages (lines 412-413).
struct AddTodoForm: View {
    var onAdd: (_ title: String, _ minutes: Double, _ importance: Importance) -> Void

    @State private var title: String = ""
    @State private var minutesText: String = ""
    @State private var importance: Importance = .normal
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Task", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            HStack(spacing: 10) {
                TextField("Estimated time (min)", text: $minutesText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submit)

                Picker("Importance", selection: $importance) {
                    ForEach(Importance.allCases, id: \.self) { level in
                        Text("\(level.rawValue) — \(level.label)").tag(level)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: submit) {
                Text("Add task")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func submit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Enter a task name first."
            return
        }
        guard let minutes = Double(minutesText), minutes > 0 else {
            errorMessage = "Enter an estimated time greater than zero."
            return
        }

        errorMessage = nil
        onAdd(trimmedTitle, minutes, importance)

        title = ""
        minutesText = ""
        importance = .normal
    }
}

#Preview {
    AddTodoForm(onAdd: { _, _, _ in })
        .padding()
}
