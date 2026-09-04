import SwiftUI
import WSPTCore

/// The add-task form: task name, estimated hours, importance picker.
/// Mirrors the `.panel` form in docs/wspt-todo.html (lines 261-286),
/// including its validation messages (lines 412-413).
struct AddTodoForm: View {
    var onAdd: (_ title: String, _ hours: Double, _ importance: Importance) -> Void

    @State private var title: String = ""
    @State private var hoursText: String = ""
    @State private var importance: Importance = .normal
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Task", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            HStack(spacing: 10) {
                TextField("Estimated time (hrs)", text: $hoursText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
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
        guard let hours = Double(hoursText), hours > 0 else {
            errorMessage = "Enter an estimated time greater than zero."
            return
        }

        errorMessage = nil
        onAdd(trimmedTitle, hours, importance)

        title = ""
        hoursText = ""
        importance = .normal
    }
}

#Preview {
    AddTodoForm(onAdd: { _, _, _ in })
        .padding()
}
