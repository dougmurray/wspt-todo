#if os(macOS)
import SwiftUI
import WSPTCore

/// Small popover form for editing an existing task's title, estimated
/// time, and importance — the mockup's Plot-tab "Edit" action needs it,
/// and `PriorityListView` exposes the same action on hover so the
/// capability isn't Plot-only. Mirrors `AddTodoForm`'s validation rules
/// (non-empty trimmed title, minutes > 0) since it's editing the same
/// fields that form creates.
struct EditTaskPopover: View {
    let initialTitle: String
    let initialMinutes: Double
    let initialImportance: Importance
    var onSave: (_ title: String, _ minutes: Double, _ importance: Importance) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var minutesText: String
    @State private var importance: Importance
    @State private var errorMessage: String?

    init(
        initialTitle: String,
        initialMinutes: Double,
        initialImportance: Importance,
        onSave: @escaping (_ title: String, _ minutes: Double, _ importance: Importance) -> Void
    ) {
        self.initialTitle = initialTitle
        self.initialMinutes = initialMinutes
        self.initialImportance = initialImportance
        self.onSave = onSave
        _title = State(initialValue: initialTitle)
        _minutesText = State(initialValue: MacPriorityTheme.plainMinutes(initialMinutes))
        _importance = State(initialValue: initialImportance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Edit task")
                .font(MacPriorityTheme.sans(12.5, weight: .semibold))
                .foregroundStyle(MacPriorityTheme.ink(0.6))

            TextField("Task", text: $title)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(MacPriorityTheme.ink)
                .onSubmit(submit)

            HStack(spacing: 10) {
                TextField("Minutes", text: $minutesText)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(MacPriorityTheme.ink)
                    .onSubmit(submit)
                    .frame(width: 90)

                Picker("Importance", selection: $importance) {
                    ForEach(Importance.allCases, id: \.self) { level in
                        Text("\(level.rawValue) — \(level.label)").tag(level)
                    }
                }
                .labelsHidden()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(MacPriorityTheme.sans(11))
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save", action: submit)
                    .buttonStyle(.borderedProminent)
                    .tint(MacPriorityTheme.accent)
            }
        }
        .padding(16)
        .frame(width: 260)
        // Popovers are a separate window/hosting hierarchy on macOS and
        // don't reliably inherit `macBody`'s forced light appearance —
        // pin it here too so typed text stays dark-on-cream regardless of
        // system Dark Mode.
        .preferredColorScheme(.light)
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
        onSave(trimmedTitle, minutes, importance)
        dismiss()
    }
}
#endif
